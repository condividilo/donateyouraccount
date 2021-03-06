require 'spec_helper'

describe FacebookStatus do
    def app
    Dya::Application
    end

    it "should publish a Facebook status" do
        facebook_page_uid="234324"
        FakeWeb.register_uri(:get, "https://graph.facebook.com/234324",
                     :content_type => "application/json",
                     :body => json_fixture('facebook/page.json', :id => facebook_page_uid))

        FakeWeb.register_uri(:get, "https://graph.facebook.com/234324/feed",
                     :content_type => "application/json",
                     :body => json_fixture('facebook/feed.json', :id => facebook_page_uid))

        FakeWeb.register_uri(:get, "https://graph.facebook.com/234324_108471362651205",
                     :content_type => "application/json",
                     :body => json_fixture('facebook/post.json', :id => "234324_108471362651205", :page_id=>"234324"))

        FakeWeb.register_uri(:post, "https://graph.facebook.com/me/links",
                     :content_type => "application/json",
                     :body => "{}")

        # Accept post back from Facebook
        FakeWeb.register_uri(:post, "https://graph.facebook.com/oauth/access_token",
                         :content_type => "application/json",
                         :body => json_fixture('facebook/oauth_access_token'))

        account = create(:facebook_account, uid: "123456", facebook_pages: "[#{json_fixture('facebook/page.json', :id => facebook_page_uid)}]")
        donor_account = create(:facebook_account, uid: "234222")
        campaign = create(:campaign, facebook_account_id: account.id, permalink: "test", facebook_page_uid: "234324", facebook_page: json_fixture('facebook/page.json', :id => facebook_page_uid))
        donation = create(:donation, account_id: donor_account.id, campaign_id: campaign.id)

        ApplicationController.any_instance.stub(:current_facebook_account).and_return(account)

        get campaign_path(campaign)
        last_response.status.should==200

        get new_campaign_facebook_status_path(campaign)
        last_response.status.should==200

        post campaign_facebook_statuses_path(campaign), {facebook_status: {"uid" => "#{facebook_page_uid}_108471362651205", "levels" => ["2"]}}
        last_response.status.should==302
        last_response.headers["Location"].should match /^http\:\/\/.+\/test$/
        follow_redirect!

        last_response.status.should==200
        campaign.facebook_statuses.count.should==1

        campaign.facebook_statuses.first.publish

        campaign.facebook_statuses.first.donated_statuses.count.should==1
    end
end