puts 'hello to ruby scrap file'
$globalVar = 'You can access me at any time now from anywhere in this ruby execution'
class Test < Object #object is implied usually,
  @classInstanceVariable
  @@classVariable = 0
  Iamconstant = 'constantly'
  attr_accessor :thing1
  attr_reader :thing2
  attr_writer :thing2 #combining these two things is equal to what we do to thing1

  def initialize(thing1, thing2)
    @thing1 = thing1
    @thing2 = thing2
  end

  def info
    current = self.class
    puts "Starting info at: #{current}"
    until current.nil?
      p current
      current = current.superclass
    end
    localVar = 'you cant access me outside of method info'
  end

  def self.classVariable
    @@classVariable
  end

  def self.setclassVariable( var )
    @@classVariable = var
  end

  def self.classInstanceVariable
    @classInstanceVariable
  end

  def self.setclassInstanceVariable( var )
    @classInstanceVariable = var
  end
end

test1 = Test.new('string1', 'string2')
test2 = Test.new('string3', 'string4')


Test.setclassVariable 'apple pie'
p Test.classVariable
Test.setclassInstanceVariable 'cherry pie'
p Test.classInstanceVariable
test1.info

class TestMore < Test
  @classVariable = 'overwritten'
end

testMore = TestMore.new('string5', 'string6')

testMore.info
p TestMore.classVariable
p TestMore.classInstanceVariable

puts $globalVar



puts test1.thing1
puts test2.thing1
