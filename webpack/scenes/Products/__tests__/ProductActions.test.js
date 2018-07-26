import thunk from 'redux-thunk';
import Immutable from 'seamless-immutable';
import configureMockStore from 'redux-mock-store';
import { mockRequest, mockErrorRequest, mockReset } from '../../../mockRequest';
import {
  failureActions,
  successActions,
} from './products.fixtures';
import loadProducts from '../ProductActions';

const mockStore = configureMockStore([thunk]);
const store = mockStore({ e: Immutable({}) });

afterEach(() => {
  store.clearActions();
  mockReset();
});

describe('product actions', () => {
  describe('loadProducts', () => {
    it(
      'creates PRODUCTS_REQUEST and then fails with 422',
      () => {
        mockErrorRequest({
          url: '/katello/api/v2/organizations/1/products',
          status: 422,
        });
        return store.dispatch(loadProducts())
          .then(() => expect(store.getActions()).toEqual(failureActions));
      },
    );

    it(
      'creates SUBSCRIPTIONS_REQUEST and ends with success',
      () => {
        mockRequest({
          url: '/katello/api/v2/subscriptions',
          response: requestSuccessResponse,
        });
        return store.dispatch(loadProducts())
          .then(() => expect(store.getActions()).toEqual(successActions));
      },
    );

    it(
      'creates SUBSCRIPTIONS_REQUEST and triggers loadAvailableQuantities when there is some RH subscription',
      () => {
        mockRequest({
          url: '/katello/api/v2/subscriptions',
          response: requestSuccessResponseWithRHSubscriptions,
        });
        return store.dispatch(loadProducts())
          .then(() =>
            expect(store.getActions())
              .toEqual(successActionsWithQuantityLoad));
      },
    );
  });

  describe('updateQuantity', () => {
    it(
      'creates UPDATE_QUANTITY_REQUEST and then fails with 422',
      () => {
        mockErrorRequest({
          method: 'PUT',
          url: '/katello/api/v2/organizations/1/upstream_subscriptions',
          data: { pools: poolsUpdate },
          status: 422,
        });
        return store.dispatch(updateQuantity(poolsUpdate))
          .then(() => expect(store.getActions()).toEqual(updateQuantityFailureActions));
      },
    );
    it(
      'creates UPDATE_QUANTITY_REQUEST and ends with success',
      () => {
        mockRequest({
          method: 'PUT',
          url: '/katello/api/v2/organizations/1/upstream_subscriptions',
          data: { pools: poolsUpdate },
          response: requestSuccessResponse,
        });
        return store.dispatch(updateQuantity(poolsUpdate))
          .then(() => expect(store.getActions()).toEqual(updateQuantitySuccessActions));
      },
    );
  });

  describe('loadAvailableQuantities', () => {
    const data = { pool_ids: [5] };

    it(
      'creates SUBSCRIPTIONS_QUANTITIES_REQUEST and then fails with 500',
      () => {
        mockErrorRequest({
          method: 'GET',
          url: '/katello/api/v2/organizations/1/upstream_subscriptions',
          data,
          status: 500,
        });
        return store.dispatch(loadAvailableQuantities())
          .then(() => expect(store.getActions()).toEqual(loadQuantitiesFailureActions));
      },
    );
    it(
      'creates SUBSCRIPTIONS_QUANTITIES_REQUEST and ends with success',
      () => {
        mockRequest({
          method: 'GET',
          url: '/katello/api/v2/organizations/1/upstream_subscriptions',
          data,
          response: quantitiesRequestSuccessResponse,
        });
        return store.dispatch(loadAvailableQuantities())
          .then(() => expect(store.getActions()).toEqual(loadQuantitiesSuccessActions));
      },
    );
  });
});
