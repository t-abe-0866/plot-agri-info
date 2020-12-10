class HomesController < ApplicationController
  before_action :require_user_logged_in
  
  def index
    @users = User.order(id: :desc).page(params[:page]).per(25)
    @map = Map.new
    @maps = current_user.maps.all
  end
  
  def create
    @map = current_user.maps.find_or_initialize_by(map_params)

    @map.latitude = params[:latitude]
    @map.longitude = params[:longitude]

    if @map.save
      flash[:success] = 'プロットを登録しました。'
    else
      flash.now[:danger] = 'プロットの登録に失敗しました。'
      @maps = current_user.maps.all
    end
    redirect_to root_url
  end

  private
  # ストロングパラメーター
  def map_params
    params.require(:map).permit( :plot_no)#, :user_id,　:address, :latitude, :longitude)
  end
  
  def correct_user
    @map = current_user.maps.find_by(id: params[:id])
    unless @map
      redirect_to root_url
    end
  end
end
