class ApplicationController < ActionController::Base
  
  include SessionsHelper
  
  private
  
  def require_user_plot
    @result = false
    for i in 1..8
      if @map = current_user.maps.find_by(plot_no: i)
        @plot_no = i
        @result = true
      end
    end
    if @result == false
      flash.now[:danger] = 'マップにプロットがありません。'
      redirect_to root_url
    end
  end

  def require_user_logged_in
    unless logged_in?
      redirect_to login_url
    end
  end
end
