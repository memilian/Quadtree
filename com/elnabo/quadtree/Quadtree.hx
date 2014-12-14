package com.elnabo.quadtree;

import de.polygonal.ds.DLL;
import de.polygonal.ds.DLLNode;

/**
 * Quadtree data structure.
 */
class Quadtree<T : QuadtreeElement>
{
	/** List of entities in this node. */
	private var entities:DLL<T>;
	/** The boundaries of this node. */
	private var boundaries:Box;
	/** The depth of this node. */
	private var depth:Int = 0;
	/** The maximum depth of this tree */
	private var maxDepth:Int;
	/**
	 * The minimum number of elements in a node
	 * before splitting. *
	 */
	private var minElementBeforeSplit:Int;
	
	// Children 
	/** Top left child. */
	private var topLeft:Quadtree<T> = null;
	/** Top right child. */
	private var topRight:Quadtree<T> = null;
	/** Bottom right child. */
	private var bottomRight:Quadtree<T> = null;
	/** Bottom left child. */
	private var bottomLeft:Quadtree<T> = null;
	
	/**
	 * Create a new quadtree.
	 * 
	 * @param boundaries The bounds of the tree.
	 * @param minElementBeforeSplit The minimum number element in a node before spliting.
	 * @param maxDepth  The maximum depth of the tree.
	 * 
	 */
	public inline function new(boundaries:Box, ?minElementBeforeSplit:Int=5, ?maxDepth:Int=2147483647)
	{
		entities = new DLL<T>(minElementBeforeSplit);
		this.boundaries = boundaries.clone();
		this.minElementBeforeSplit = minElementBeforeSplit;
		this.maxDepth = maxDepth;
	}
	
	/**
	 * Add an element to the tree.
	 * 
	 * @param element The element.
	 * 
	 * @return True if the element was added, else false.
	 */
	public inline function add(element:T):Bool
	{
		if (!boundaries.contains(element.box()))
			return false;
			
		// Try to add it in a children.
		var added:Bool = false;
		if (depth < maxDepth && entities.size() >=  minElementBeforeSplit)
		{
			if (topLeft == null)
				split();
			
			if (topLeft.add(element)) { added = true;}
			else if (topRight.add(element)) { added = true;}
			else if (bottomRight.add(element)) { added = true;}
			else if (bottomLeft.add(element)) { added = true;}
		}
		
		// Add here.
		if (!added) { entities.append(element); }
		return true;
	}
	
	/**
	 * Return all the element who collide with a given box.
	 * 
	 * @param box  The box.
	 * 
	 * @return The list of element who collide with the box.
	 */
	public inline function getCollision(box:Box, ?output:DLL<T>):DLL<T>
	{
		if (output == null) 
			output = new DLL<T>();
		if (!boundaries.intersect(box))
			return output;
		
		// Add all from this level who intersect;
		var node:DLLNode<T> = entities.head;
		while (node != null) 
		{
			if (box.intersect(node.val.box()))
			{
				output.append(node.val);
			}
			node = node.next;
		}
		
		if (topLeft == null)
			return output;
			
		// Test if children contain some.
		topLeft.getCollision(box, output);
		topRight.getCollision(box, output);
		bottomRight.getCollision(box, output);
		return bottomLeft.getCollision(box, output);
		
	}
	
	/**
	 * Return all the element who don't collide with a given box.
	 * 
	 * @param box  The box.
	 * 
	 * @return The list of element who don't collide with the box.
	 */
	public inline function getExclusion(box:Box, ?output:DLL<T>):DLL<T>
	{
		if (output == null) 
			output = new DLL<T>();
		if (boundaries.inside(box))
			return output;
			
		var node:DLLNode<T> = entities.head;
		while (node != null) 
		{
			if (!box.intersect(node.val.box()))
			{
				output.append(node.val);
			}
			node = node.next;
		}
		
		if (topLeft == null)
			return output;
		
		// Test if children contain some.
		topLeft.getExclusion(box, output);
		topRight.getExclusion(box, output);
		bottomRight.getExclusion(box, output);
		return bottomLeft.getExclusion(box, output);
	}
	
	/**
	 * Return all the elements.
	 * 
	 * @param box  The box.
	 * 
	 * @return The list of elements.
	 */
	public inline function getAll(?output:DLL<T>):DLL<T>
	{
		if (output == null) 
			output = new DLL<T>();
			
		var node:DLLNode<T> = entities.head;
		while (node != null) 
		{
			output.append(node.val);
			node = node.next;
		}
		
		if (topLeft == null)
			return output;
		
		// Test if children contain some.
		topLeft.getAll(output);
		topRight.getAll(output);
		bottomRight.getAll(output);
		return bottomLeft.getAll(output);
	}
	
	/**
	 * Create a new tree node.
	 * 
	 * Only used to create children.
	 * 
	 * @param boundaries The boundaries of the new node.
	 * 
	 * @return A new tree.
	 */
	private inline function getChildTree(boundaries:Box):Quadtree<T>
	{
		var child:Quadtree<T> = new Quadtree<T>(boundaries,minElementBeforeSplit,maxDepth);
		child.depth = depth + 1;
		return child;
	}
	
	/**
	 * Split the current node to add children.
	 * Rebalance the current entities if they can't fit in a lower node.
	 */
	private inline function split():Void
	{
		var leftWidth:Int = Std.int(boundaries.width/2);
		var topHeight:Int = Std.int(boundaries.height/2);
		
		var rightStartX:Int = boundaries.x + leftWidth + 1;
		var rightWidth:Int = boundaries.width - (leftWidth +1);
		
		var botStartY:Int = boundaries.y + topHeight + 1;
		var botHeight:Int = boundaries.height - (topHeight + 1);
		
		topLeft = getChildTree(new Box(boundaries.x, boundaries.y, leftWidth, topHeight));
		topRight = getChildTree(new Box(rightStartX, boundaries.y, rightWidth, topHeight));
		bottomRight = getChildTree(new Box(rightStartX, botStartY, rightWidth, botHeight));
		bottomLeft = getChildTree(new Box(boundaries.x, botStartY, leftWidth, botHeight));
		
		balance();		
	}
	
	/**
	 * Move entities who can fit in a lower node.
	 */
	private inline function balance():Void
	{
		var node:DLLNode<T> = entities.head;
		while (node != null) 
		{
			var val:T = node.val;
			if (topLeft.add(val) || topRight.add(val) ||
				bottomRight.add(val) || bottomLeft.add(val))
			{
				entities.remove(val);
			}
			node = node.next;
		}
	}
	
	/**
	 * Remove an element of the tree.
	 * Doesn't change its datastructure.
	 * 
	 * @param e The element.
	 * 
	 * @return True if the element has been removed, else false.
	 */
	public inline function remove(e:T):Bool
	{
		if (topLeft == null)
			return entities.remove(e);
			
		return entities.remove(e)||	topLeft.remove(e)||
			topRight.remove(e)||bottomRight.remove(e)||
			bottomLeft.remove(e);
	}
}
