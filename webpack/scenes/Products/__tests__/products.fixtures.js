import Immutable from 'seamless-immutable';
import { toastErrorAction, failureAction } from '../../../services/api/testHelpers';

export const initialState = Immutable({
  loading: true,
  results: [],
  pagination: {
    page: 0,
    perPage: 20,
  },
  itemCount: 0,
  quantitiesLoading: false,
  availableQuantities: null,
  tasks: [],
});

export const loadingState = Immutable({
  ...initialState,
});

export const emptyState = Immutable({
  ...loadingState,
  loading: false,
});

export const requestSuccessResponse = Immutable({
  organization: {},
  total: 81,
  subtotal: 81,
  page: 1,
  per_page: 2,
  error: null,
  search: null,
  sort: {
    by: 'name',
    order: 'asc',
  },
  results: [
    {
      id: 114,
      cp_id: "69",
      name: "Red Hat Enterprise Linux Server",
      label: "Red_Hat_Enterprise_Linux_Server",
      description: null,
      provider_id: 2,
      sync_plan_id: null,
      sync_summary: {},
      gpg_key_id: null,
      ssl_ca_cert_id: null,
      ssl_client_cert_id: null,
      ssl_client_key_id: null,
      sync_state: null,
      last_sync: null,
      last_sync_words: null,
      organization_id: 1,
      organization: {
        name: "Default Organization",
        label: "Default_Organization",
        id: 1
      },
      available_content: [
        {
          enabled: true,
          product_id: 114,
          content: {
            name: "Red Hat Enterprise Linux 7 Server (RPMs)",
            label: "rhel-7-server-rpms",
            vendor: "Red Hat",
            content_url: "/content/dist/rhel/server/7/$releasever/$basearch/os",
            gpg_url: "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release",
            id: "2456",
            type: "yum",
            gpgUrl: "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release",
            contentUrl: "/content/dist/rhel/server/7/$releasever/$basearch/os"
          }
        }
      ],
      sync_plan: null,
      repository_count: 1
    }
  ],
});

const request = {
  type: 'PRODUCTS_REQUEST'
};

export const successActions = [
  request,
  {
    type: 'PRODUCTS_SUCCESS',
    response: requestSuccessResponse,
    search: undefined,
  },
];

export const failureActions = [
  {
    type: 'PRODUCTS_REQUEST',
  },
  failureAction('PRODUCTS_FAILURE'),
  toastErrorAction(),
];
