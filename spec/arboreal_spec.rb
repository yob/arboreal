require 'spec_helper'

require 'arboreal'

class Node < ActiveRecord::Base
  
  acts_arboreal
  
  class Migration < ActiveRecord::Migration

    def self.up
      create_table "nodes", :force => true do |t|
        t.string "name"
        t.string "type"
        t.integer "parent_id"
        t.string "ancestry_string"
      end
    end

    def self.down
      drop_table "nodes"
    end

  end
  
end

describe "Arboreal hierarchy" do

  before(:all) do
    Node::Migration.up
  end
  
  after(:all) do
    Node::Migration.down
  end

  before do
    @australia = Node.create!(:name => "Australia")
    @victoria = @australia.children.create!(:name => "Victoria")
    @melbourne = @victoria.children.create!(:name => "Melbourne")
    @nsw = @australia.children.create!(:name => "New South Wales")
    @sydney = @nsw.children.create!(:name => "Sydney")
  end
  
  describe "node" do
  
    describe "#parent" do
      it "returns the parent" do
        @victoria.parent.should == @australia
      end
    end

    describe "#children" do
      it "returns the children" do
        @australia.children.to_set.should == [@victoria, @nsw].to_set
      end
    end

    describe "#siblings" do
      it "returns other nodes with the same parent" do
        @victoria.siblings.should == [@nsw]
      end
    end
    
    it "cannot be it's own parent" do
      lambda do
        @australia.update_attributes!(:parent => @australia)
      end.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "cannot be it's own ancestor" do
      lambda do
        @australia.update_attributes!(:parent => @melbourne)
      end.should raise_error(ActiveRecord::RecordInvalid)
    end

  end
    
  describe "root node" do
  
    describe "#parent" do
      it "returns nil" do
        @australia.parent.should == nil
      end
    end

    describe "#ancestors" do
      it "is empty" do
        @australia.ancestors.should be_empty
      end
    end
    
    describe "#ancestry_string" do
      it "is a single dash" do
        @australia.ancestry_string.should == "-"
      end
    end

    describe "#path_string" do
      it "contains only the id of the root" do
        @australia.path_string.should == "-#{@australia.id}-"
      end
    end

    describe "#descendants" do

      it "includes children" do
        @australia.descendants.should include(@victoria)
        @australia.descendants.should include(@nsw)
      end

      it "includes grand-children" do
        @australia.descendants.should include(@melbourne)
        @australia.descendants.should include(@sydney)
      end

      it "excludes self" do
        @australia.descendants.should_not include(@australia)
      end

    end

    describe "#subtree" do

      it "includes children" do
        @australia.subtree.should include(@victoria)
        @australia.subtree.should include(@nsw)
      end

      it "includes grand-children" do
        @australia.subtree.should include(@melbourne)
        @australia.subtree.should include(@sydney)
      end

      it "includes self" do
        @australia.subtree.should include(@australia)
      end

    end

    describe "#root" do
      
     it "is itself" do
       @australia.root.should == @australia
     end
     
    end
    
  end
  
  describe "leaf node" do

    describe "#ancestry_string" do
      it "contains ids of all ancestors" do
        @melbourne.ancestry_string.should == "-#{@australia.id}-#{@victoria.id}-"
      end
    end

    describe "#path_string" do
      it "contains ids of all ancestors, plus self" do
        @melbourne.path_string.should == "-#{@australia.id}-#{@victoria.id}-#{@melbourne.id}-"
      end
    end

    describe "#ancestors" do
      
      it "returns all ancestors, depth-first" do
        @melbourne.ancestors.all.should == [@australia, @victoria]
      end
      
    end

    describe "#children" do
      it "returns an empty collection" do
        @melbourne.children.should be_empty
      end
    end

    describe "#descendants" do
      it "returns an empty collection" do
        @melbourne.children.should be_empty
      end
    end

    describe "#root" do

      it "is the root of the tree" do
        @melbourne.root.should == @australia
      end

    end

  end
  
  describe ".roots" do
    
    it "returns root nodes" do
      @nz = Node.create!(:name => "New Zealand")
      Node.roots.to_set.should == [@australia, @nz].to_set
    end
    
  end

  describe "when a node changes parent" do

    before do
      @box_hill = Node.create!(:name => "Box Hill", :parent => @melbourne)
      @nz = Node.create!(:name => "New Zealand")
      @victoria.update_attributes!(:parent => @nz)
    end
    
    describe "each descendant" do
      
      it "follows" do

        @melbourne.reload
        @melbourne.ancestors.should include(@nz, @victoria)
        @melbourne.ancestors.should_not include(@australia)

        @box_hill.reload
        @box_hill.ancestors.should include(@nz, @victoria, @melbourne)
        @box_hill.ancestors.should_not include(@australia)

      end
      
    end
    
  end
  
  describe "node created using find_or_create_by" do
    
    before do
      @tasmania = @australia.children.find_or_create_by_name("Tasmania")
    end
    
    it "still has the right ancestry" do
      @tasmania.ancestors.should == [@australia]
    end
    
  end
  
  describe ".rebuild_ancestry" do

    before do
      Node.connection.update("UPDATE nodes SET ancestry_string = 'corrupt'")
      Node.rebuild_ancestry
    end
    
    it "re-populates all ancestry_strings" do
      Node.count(:conditions => {:ancestry_string => 'corrupt'}).should == 0
    end

    it "fixes the hierarchy" do
      @melbourne.reload.ancestors.should == [@australia, @victoria]
      @sydney.reload.ancestors.should == [@australia, @nsw]
    end
    
  end
  
end

class RedNode < Node; end
class GreenNode < Node; end
class BlueNode < Node; end
  
describe "polymorphic hierarchy" do

  before(:all) do
    Node::Migration.up
  end
  
  after(:all) do
    Node::Migration.down
  end

  before do
    @red = RedNode.create!
    @green = GreenNode.create!(:parent => @red)
    @blue = BlueNode.create!(:parent => @green)
  end
  
  describe "#descendants" do
    it "includes nodes of other types" do
      @red.descendants.should include(@green, @blue)
    end
  end

  describe "#subtree" do
    it "includes nodes of other types" do
      @red.subtree.should include(@red, @green, @blue)
    end
  end

  describe "#ancestors" do
    it "includes nodes of other types" do
      @blue.ancestors.should include(@red, @green)
    end
  end
  
end
