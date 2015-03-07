card_accessor :followers

FOLLOWER_IDS_CACHE_KEY = 'FOLLOWER_IDS'

event :cache_expired_because_of_new_set, :before=>:store, :on=>:create, :when=>proc { |c| c.type_id == Card::SetID } do
  Card.follow_caches_expired
end

event :cache_expired_because_of_type_change, :before=>:store, :changed=>:type_id do  #FIXME expire (also?) after save
  Card.follow_caches_expired
end

event :cache_expired_because_of_name_change, :before=>:store, :changed=>:name do
  Card.follow_caches_expired
end

event :cache_expired_because_of_new_user_rule, :before=>:extend, :when=>proc { |c| c.follow_rule_card? }  do
  Card.follow_caches_expired
end

format do
    
  def follow_link_hash args
    toggle = args[:toggle] || ( card.followed? ? :off : :on )
    hash = { :class => "follow-toggle-#{toggle}" }

    case toggle
    when :off
      hash[:content] = '*never'
      hash[:title]   = "stop sending emails about changes to #{card.follow_label}"
      hash[:verb]    = 'unfollow'
    when :on
      hash[:content] = '*always'
      hash[:title]   = "send emails about changes to #{card.follow_label}"
      hash[:verb]    = 'follow'
    end
    hash
      
  end
  
  
end


format :json do
  view :follow_status do |args|
    follow_link_hash args
  end
end

format :html do
 
  view :follow_link, :tags=>:unknown_ok, :perms=>:none do |args|
    hash = follow_link_hash args
    text = %[<span class="follow-verb">#{hash[:verb]}</span> #{args[:label]}]
    opts = {
      :title           => hash[:title],
      :class           => "follow-toggle #{hash[:class]}",
      'data-follow'    => JSON(hash),
      'data-rule_name' => card.default_follow_set_card.follow_rule_name( Auth.current.name ).to_name.url_key,
      'data-card_key'  => card.key
    }
    link_to text, '', opts
  end
  
  def default_follow_link_args args
    args[:toggle] ||=  card.followed? ? :off : :on
    args[:label]  ||=  card.follow_label
  end
  
end


def follow_label
  name
end

def followers
  follower_ids.map do |id|
    Card.fetch(id)
  end
end

def follower_names
  followers.map(&:name)
end


def follow_rule_card?
  is_user_rule? && rule_setting_name == '*follow'
end

def follow_option?
  codename && Card::FollowOption.codenames.include?(codename.to_sym) 
end

# used for the follow menu
# overwritten in type/set.rb and type/cardtype.rb
# for sets and cardtypes it doesn't check whether the users is following the card itself
# instead it checks whether he is following the complete set
def followed_by? user_id
  if follow_rule_applies? user_id
    return true
  end
  left_card = left
  while left_card
    if left_card.followed_field?(self) && left_card.follow_rule_applies?(user_id)
      return true
    end
    left_card = left_card.left
  end
  return false
end

def followed?
  followed_by? Auth.current_id 
end


def follow_rule_applies? user_id
  follow_rule = rule :follow, :user_id=>user_id
  if follow_rule.present?
    follow_rule.split("\n").each do |value|
      value_code = value.to_name.code
      if test = Card::FollowOption.test[ value_code ]
        return test.call :user_id => user_id
      else
        #Rails.logger.debug "didn't find block for #{ value }"
      end
    end
  end 
  return false
end


def editor_ids_follow_cache
  @editor_ids_follow_cache ||= Card.search(:editor_of=>name, :return=>:id)
end


# the set card to be followed if you want to follow changes of card
def default_follow_set_card
  Card.fetch("#{name}+*self")
end


# returns true if according to the follow_field_rule followers of self also 
# follow changes of field_card
def followed_field? field_card
  (follow_field_rule = rule_card(:follow_fields)) || follow_field_rule.item_names.find do |item|
     item.to_name.key == field_card.key ||  (item.to_name.key == Card[:includes].key && included_card_ids.include?(field_card.id) )
  end
end

def follower_ids
  @follower_ids = read_follower_ids_cache || begin
    result = direct_follower_ids
    left_card = left
    while left_card
      if left_card.followed_field? self
        result += left_card.direct_follower_ids
      end
      left_card = left_card.left
    end
    write_follower_ids_cache result
    result
  end
end


def direct_followers
  direct_follower_ids.map do |id|
    Card.fetch(id)
  end
end

# all ids of users that follow this card because of a follow rule that applies to this card
# doesn't include users that follow this card because they are following parent cards or other cards that include this card
def direct_follower_ids args={}  
  result = ::Set.new
  set_names.each do |set_name| 
    set_card = Card.fetch(set_name)
    set_card.all_user_ids_with_rule_for(:follow).each do |user_id|
      if (!result.include? user_id) and self.follow_rule_applies?(user_id)
        result << user_id
      end
    end
  end
  result
  #ensure
  #@editor_ids_follow_cache = nil
end

def all_direct_follower_ids_with_reason
  visited = ::Set.new
  set_names.each do |set_name| 
    set_card = Card.fetch(set_name)
    set_card.all_user_ids_with_rule_for(:follow).each do |user_id|
      if (!visited.include?(user_id)) && (follow_option_card = self.follow_rule_applies?(user_id))
        visited << user_id
        yield(user_id, :set_card=>set_card, :option_card=>follow_option_card)
      end
    end
  end
  #ensure
  #@editor_ids_follow_cache = nil
end



#~~~~~ cache methods

def write_follower_ids_cache user_ids
  hash = Card.follower_ids_cache
  hash[id] = user_ids
  Card.write_follower_ids_cache hash
end

def read_follower_ids_cache
  Card.follower_ids_cache[id]
end

module ClassMethods

  def follow_caches_expired
    Card.clear_follower_ids_cache
    Card.clear_user_rule_cache
  end

  def follower_ids_cache
    Card.cache.read(FOLLOWER_IDS_CACHE_KEY) || {}
  end
  
  def write_follower_ids_cache hash
    Card.cache.write FOLLOWER_IDS_CACHE_KEY, hash
  end

  def clear_follower_ids_cache
    Card.cache.write FOLLOWER_IDS_CACHE_KEY, nil
  end

end

