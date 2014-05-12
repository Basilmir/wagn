load 'spec/mods/zfactory/lib/factory_spec.rb'
load 'spec/mods/zfactory/lib/supplier_spec.rb'

describe Card::Set::Type::Css do
  let(:css) { '#box { display: block }' }
  let(:compressed_css) {  "#box{display:block}\n" }
  let(:changed_css) { '#box { display: inline }' }
  let(:compressed_changed_css) { "#box{display:inline}\n" }
    
  it "should highlight code" do
    Card::Auth.as_bot do
      css_card = Card.create! :name=>'tmp css', :type_code=>'css', :content=>"p { border: 1px solid black }"
      assert_view_select css_card.format.render_core, 'div[class=CodeRay]'
    end
  end

  it_behaves_like "a supplier"  do
    let(:create_supplier_card) { Card.gimme! "test css", :type => :css, :content => css }
    let(:create_factory_card)  { Card.gimme! "style with css+*style", :type => :pointer }
    let(:card_content) do
       { in:       css,         out:     compressed_css, 
         new_in:   changed_css, new_out: compressed_changed_css }
    end
  end

  it_behaves_like 'a content card factory', that_produces_css do
    let(:factory_card) {  Card.gimme! "test css", :type => :css, :content => css }
    let(:card_content) do
       { in:       css,         out:     compressed_css, 
         new_in:   changed_css, new_out: compressed_changed_css }
    end
  end
end