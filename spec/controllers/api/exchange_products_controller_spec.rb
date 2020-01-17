require 'spec_helper'

module Api
  describe ExchangeProductsController, type: :controller do
    include AuthenticationWorkflow

    let(:order_cycle) { create(:order_cycle) }
    let(:exchange) { order_cycle.exchanges.incoming.first }
    let(:coordinator) { order_cycle.coordinator }

    let!(:renderer) { ExchangeProductsRenderer.new(order_cycle, coordinator.owner) }

    before do
      allow(controller).to receive_messages spree_current_user: coordinator.owner
      allow(ExchangeProductsRenderer).to receive(:new) { renderer }
      allow(renderer).
        to receive(:exchange_products).
        with(exchange.incoming, exchange.sender).
        and_return(products_relation)
    end

    describe "#index" do
      describe "when the product list is empty" do
        let(:products_relation) { Spree::Product.where("1=0") }

        it "handles it gracefully" do
          spree_get :index, exchange_id: exchange.id
          expect(json_response["products"].length).to eq 0
        end
      end

      describe "when a product is returned" do
        let(:products_relation) { Spree::Product.where(id: exchange.variants.first.product.id) }

        describe "when an exchange id param is provided" do
          it "uses exchange order_cycle, incoming and enterprise to fetch products" do
            spree_get :index, exchange_id: exchange.id, order_cycle_id: 666, enterprise_id: 666, incoming: false
            expect(json_response["products"].first["supplier_name"]).to eq exchange.variants.first.product.supplier.name
          end
        end

        describe "when an exchange id param is not provided" do
          it "uses params order_cycle, incoming and enterprise to fetch products" do
            spree_get :index, order_cycle_id: order_cycle.id, enterprise_id: exchange.sender_id, incoming: true
            expect(json_response["products"].first["supplier_name"]).to eq exchange.variants.first.product.supplier.name
          end
        end
      end

      describe "pagination" do
        let(:exchange) { order_cycle.exchanges.outgoing.first }
        let(:products_relation) { Spree::Product.includes(:variants).where("spree_variants.id": exchange.variants.map(&:id)) }

        it "paginates results" do
          spree_get :index, exchange_id: exchange.id, page: 1, per_page: 1

          expect(json_response["products"].size).to eq 1
          expect(json_response["pagination"]["results"]).to eq 2
          expect(json_response["pagination"]["pages"]).to eq 2
        end
      end
    end
  end
end