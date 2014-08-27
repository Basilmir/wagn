# -*- encoding : utf-8 -*-

describe Card::Set::Right::WhenLastEdited do
  it 'should produce a text date' do
    render_card( :core, :name=>'A+*when last edited' ).should =~ /\w+ \d+/
  end
end