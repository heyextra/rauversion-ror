class EventTicketsController < ApplicationController

  def show
    @purchased_item = PurchasedItem.find_by_decoded_id(params[:id])
    @ticket = @purchased_item.purchased_item
    @purchase = @purchased_item.purchase
    @event = @purchase.purchasable
    @is_manager = @event.user_id == current_user.id || @event.managers.includes?(current_user)
  end

  def update
    @purchased_item = PurchasedItem.find_by_decoded_id(params[:id])
    @ticket = @purchased_item.purchased_item
    @purchase = @purchased_item.purchase
    @event = @purchase.purchasable
    @is_manager = @event.user_id == current_user.id || @event.managers.includes?(current_user)
    @purchased_item.toggle_check_in!
  end

end
