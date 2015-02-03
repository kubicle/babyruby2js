

class Contacts

  attr_reader :contacts
  
  def initialize
    @contacts = Array.new(4)
    @contacts.clear
  end
  
  def clear()
    @contacts.clear
  end
  
  def empty?
    @contacts.size == 0
  end
  
  def push(item)
    @contacts.push(item) if @contacts.find_index(item) == nil
  end
  
  def each
    @contacts.each do |x|
      yield x
    end
  end
  
  def size
    @contacts.size
  end
  
  def [](ndx)
    return @contacts[ndx]
  end

end
