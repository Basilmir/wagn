# -*- encoding : utf-8 -*-

describe Card::Set::All::RichHtml::Wrapper do  
  context "full wrapping" do
    before do
      @ocslot = Card['A'].format
    end

    it "has the appropriate attributes on open" do
      assert_view_select @ocslot.render(:open), 'div[class="card-slot open-view card-frame panel panel-default ALL TYPE-basic SELF-a"]' do
        assert_select 'div[class="card-header panel-heading"]' do
          assert_select 'h3[class="card-header-title panel-title"]'
        end
        assert_select 'div[class~="card-body"]'
      end
    end

    it "has the appropriate attributes on closed" do
      v = @ocslot.render(:closed)
      assert_view_select v, 'div[class="card-slot closed-view card-frame panel panel-default ALL TYPE-basic SELF-a"]' do
        assert_select 'div[class="card-header panel-heading"]' do
          assert_select 'h3[class="card-header-title panel-title"]'
        end
        assert_select 'div[class~="closed-content card-content"]'
      end
    end
  end
end