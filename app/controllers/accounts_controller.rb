##
# Donate Your Account (donateyouraccount.com)
# Copyright (C) 2011  Kyle Shank (kyle.shank@gmail.com)
# http://www.gnu.org/licenses/agpl.html
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
##
class AccountsController < ApplicationController
  include AccountsHelper

  before_filter :login_required, :only => [:index]

  def index
    @donated_statuses = Status.donated_through_account(current_account).desc.paginate(:page => params[:page], :per_page=>10)
    @campaign = current_account.campaign
    @status = Status.new
    @campaigns = Campaign.suggest_for(current_account.id).desc.limit(4)
  end

  def new
    redirect_to get_twitter_request_token.authorize_url.gsub("authorize","authenticate")
  end

  def create
    consumer = OAuth::Consumer.new(Twitter.consumer_key, Twitter.consumer_secret, {:site=>"http://twitter.com" })
    request_token = OAuth::RequestToken.new(consumer, session[:request_token], session[:request_token_secret])

    begin
      access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
      response = consumer.request(:get, '/account/verify_credentials.json', access_token, { :scheme => :query_string })

      case response
        when Net::HTTPSuccess
          user_info = JSON.parse(response.body)

          @account = Account.first(:conditions => {:uid => user_info["id"]})

          unless @account
            @account = Account.new(
                :uid => user_info["id"],
                :screen_name => user_info["screen_name"],
                :token => access_token.token,
                :secret => access_token.secret
            )
          end

          @account.name = user_info["name"]
          @account.followers = (user_info["followers_count"] || 0).to_i
          @account.url = user_info["url"]
          @account.description = user_info["description"]
          @account.location = user_info["location"]
          @account.profile_sidebar_border_color = user_info["profile_sidebar_border_color"]
          @account.profile_sidebar_fill_color = user_info["profile_sidebar_fill_color"]
          @account.profile_link_color = user_info["profile_link_color"]
          @account.profile_image_url = user_info["profile_image_url"]
          @account.profile_background_color = user_info["profile_background_color"]
          @account.profile_background_image_url = user_info["profile_background_image_url"]
          @account.profile_text_color = user_info["profile_text_color"]
          @account.profile_background_tile = user_info["profile_background_tile"]
          @account.profile_use_background_image = user_info["profile_use_background_image"]

          if @account.save
            self.current_account=@account
          end

          redirect_back_or_default dashboard_path
      end
    rescue OAuth::Unauthorized
      request.flash.now["notice"] = "Oops! OAuth Unauthorized error."
      redirect_to "/"
    end
  end
end
