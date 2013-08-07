#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module Katello
  class ContentViewDefinitionsController < Katello::ApplicationController

    helper ProductsHelper

    before_filter :find_content_view_definition, :only => [:clone, :show, :edit, :update, :destroy, :views, :content,
                                                           :update_content, :update_component_views,
                                                           :publish_setup, :publish, :definition_status]
    before_filter :authorize #after find_content_view_definition, since the definition is required for authorization
    before_filter :panel_options, :only => [:index, :items]

    respond_to :html

    def section_id
      'contents'
    end

    def rules
      index_rule   = lambda { current_organization && ContentViewDefinition.any_readable?(current_organization) }
      show_rule    = lambda { @view_definition.readable? }
      manage_rule  = lambda { @view_definition.editable? }
      delete_rule  = lambda { @view_definition.deletable? }
      publish_rule = lambda { @view_definition.publishable? }
      create_rule  = lambda { current_organization && ContentViewDefinition.creatable?(current_organization) }
      clone_rule   = lambda do
        ContentViewDefinition.creatable?(current_organization) && @view_definition.readable?
      end

      {
        :index => index_rule,
        :items => index_rule,
        :show => show_rule,

        :new => create_rule,
        :create => create_rule,
        :clone => clone_rule,

        :edit => show_rule,
        :update => manage_rule,

        :publish_setup => publish_rule,
        :publish => publish_rule,

        :destroy => delete_rule,

        :views => show_rule,
        :definition_status => publish_rule,

        :content => show_rule,
        :update_content => manage_rule,
        :update_component_views => manage_rule,
        :default_label => lambda {create_rule.call || manage_rule.call}
      }
    end

    def param_rules
      {
        :create => {:view_definition => [:name, :label, :description]},
        :update => {:view_definition => [:name, :description]},
        :update_content => [:id, :products, :repos]
      }
    end

    def items
      ids = ContentViewDefinition.pluck(:id)
      offset = params[:offset] || 0
      render_panel_direct(ContentViewDefinition, @panel_options, params[:search], offset, [:name_sort, 'asc'],
                          {:default_field => :name, :filter => [{:organization_id => ids}]})
    end

    def show
      render :partial=>"katello/common/list_update", :locals=>{:item=>@view_definition, :accessor=>"id", :columns=>['name']}
    end

    def new
      render :partial => "new"
    end

    def create
      @view_definition = ContentViewDefinition.create!(params[:katello_content_view_definition])

      notify.success _("Content view definition '%s' was created.") % @view_definition['name']

      if search_validate(ContentViewDefinition, @view_definition.id, params[:search])
        render :partial=>"katello/common/list_item",
               :locals=>{:item=>@view_definition, :initial_action=>:views, :accessor=>"id",
                         :columns=>['name'], :name=>controller_display_name}
      else
        notify.message _("'%s' did not meet the current search criteria and is not being shown.") % @view_definition["name"]
        render :json => { :no_match => true }
      end
    end

    def clone
      new_definition = @view_definition.copy(:name => params[:name],
                                             :description => params[:description])
      notify.success(_("Content view definition '%{new_definition_name}' created successfully as a clone of '%{definition_name}'.") %
                         {:new_definition_name => new_definition.name, :definition_name => @view_definition.name})

      render :partial => "katello/common/list_item",
             :locals  => { :item => new_definition, :initial_action => :views,
                           :accessor => "id", :columns => ["name"],
                           :name => controller_display_name }
    end

    def edit
      render :partial => "edit", :locals => {:view_definition => @view_definition,
                                             :editable => @view_definition.editable?,
                                             :name => controller_display_name}
    end

    def update
      result = params[:view_definition].nil? ? "" : params[:view_definition].values.first

      unless params[:view_definition][:description].nil?
        result = params[:view_definition][:description] = params[:view_definition][:description].gsub("\n",'')
      end

      @view_definition.update_attributes!(params[:view_definition])

      notify.success _("Content view definition '%s' was updated.") % @view_definition["name"]

      if not search_validate(ContentViewDefinition, @view_definition.id, params[:search])
        notify.message _("'%s' no longer matches the current search criteria.") % @view_definition["name"]
      end

      render :text => escape_html(result)
    end

    def destroy
      if @view_definition.destroy
        notify.success _("Content view definition '%s' was deleted.") % @view_definition[:name]
        render :partial => "katello/common/list_remove", :locals => {:id=>params[:id], :name=>controller_display_name}
      end
    end

    def publish_setup
      # retrieve the form to enable the user to request a publish
      render :partial => "publish",
             :locals => {:view_definition => @view_definition, :editable=>@view_definition.editable?,
                         :name=>controller_display_name}
    end

    def publish
      # perform the publish
      if params.has_key?(:katello_content_view)
        @view_definition.publish(params[:katello_content_view][:name],
                                 params[:katello_content_view][:description],
                                 params[:katello_content_view][:label],
                                 params[:katello_content_view][:operatingsystems],
                                 {:notify => true})

        notify.success(_("Started publish of content view '%{view_name}' from definition '%{definition_name}'.") %
                           {:view_name => params[:katello_content_view][:name], :definition_name => @view_definition.name})

        render :nothing => true
      else
        render_bad_parameters
      end
    rescue => e
      notify.exception(_("Failed to publish content view '%{view_name}' from definition '%{definition_name}'.") %
                           {:view_name => params[:katello_content_view][:name], :definition_name => @view_definition.name}, e)
      log_exception(e)

      render :text => e.to_s, :status => 500
    end

    def views
      render :partial => "katello/content_view_definitions/views/index",
             :locals => {:view_definition => @view_definition, :editable => @view_definition.editable?,
                         :name => controller_display_name}
    end

    def definition_status
      # retrieve the status for publish & refresh tasks initiated by the client
      statuses = {:task_statuses => []}

      TaskStatus.where(:id => params[:task_ids]).collect do |status|
        statuses[:task_statuses] << {
            :id => status.id,
            :pending? => status.pending?,
            :status_html => render_to_string(:template => 'katello/content_view_definitions/views/_version',
                                             :layout => false, :locals => {:version => status.task_owner,
                                                                           :task => status, :view_definition => @view_definition})
        }
      end

      render :json => statuses
    end

    def content
      if @view_definition.composite?

        component_views = @view_definition.component_content_views.inject({}) do |hash, view|
          hash[view.id] = view
          hash
        end

        render :partial => "composite_definition_content",
               :locals => {:view_definition => @view_definition,
                           :view_definitions => ContentViewDefinition.readable(@view_definition.organization).non_composite,
                           :views => component_views,
                           :editable=>@view_definition.editable?,
                           :name=>controller_display_name}
      else
        render :partial => "single_definition_content",
               :locals => {:view_definition => @view_definition, :editable=>@view_definition.editable?,
                           :name=>controller_display_name}
      end
    end

    def update_content
      if params.has_key?(:products)
        products_ids = params[:products].blank? ? [] : Product.readable(@view_definition.organization).
            where(:id => params[:products]).pluck("katello_products.id")

        @view_definition.product_ids = products_ids
      end

      if params[:repos]
        repo_ids = params[:repos].empty? ? [] : Repository.libraries_content_readable(@view_definition.organization).
            where(:id => params[:repos].values.flatten).pluck("katello_repositories.id")

        @view_definition.repository_ids = repo_ids
      end

      @view_definition.save!

      notify.success _("Successfully updated content for content view definition '%s'.") % @view_definition.name
      render :nothing => true
    end

    def update_component_views
      if params[:content_views]
        @content_views = ContentView.where(:id => params[:content_views].keys)
        deleted_content_views = @view_definition.component_content_views - @content_views
        added_content_views = @content_views - @view_definition.component_content_views

        @view_definition.component_content_views -= deleted_content_views
        @view_definition.component_content_views += added_content_views
      else
        @view_definition.component_content_views = []
      end
      @view_definition.save!

      notify.success _("Successfully updated content for content view definition '%s'.") % @view_definition.name
      render :nothing => true
    end

    protected

    def find_content_view_definition
      @view_definition = ContentViewDefinition.find(params[:id])
    end

    def panel_options
      @panel_options = {
        :title => _('Content View Definitions'),
        :col => ['name'],
        :titles => [_('Name')],
        :create => _('Key'),
        :create_label => _('+ New View Definition'),
        :name => controller_display_name,
        :ajax_load  => true,
        :ajax_scroll => items_katello_content_view_definitions_path,
        :enable_create => ContentViewDefinition.creatable?(current_organization),
        :initial_action => :views,
        :search_class => ContentViewDefinition}
    end

    private

    def controller_display_name
      return 'content_view_definition'
    end

    def search_filter
      @view_definition = {:organization_id => current_organization}
    end
  end
end