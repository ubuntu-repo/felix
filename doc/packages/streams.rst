Package: src/packages/streams.fdoc

============ ==================================
key          file                               
============ ==================================
iterator.flx share/lib/std/control/iterator.flx 
stream.flx   share/lib/std/datatype/stream.flx  
============ ==================================

===================================
Streamable data types and iterators
===================================


Iterators
=========



.. index:: Iterable(class)
.. index:: iterator(fun)
.. index:: Streamable(class)
.. code-block:: felix

  //[iterator.flx]
  //$ Class of data structures supporting streaming.
  //$ The container type just needs an iterator method.
  //$ The iterator method returns a generator which
  //$ yields the values stored in the container.
  class Iterable [C1, V] {
    virtual fun iterator : C1 -> 1 -> opt[V];
  }
  
  class Streamable[C1, V] {
    inherit Iterable[C1,V];
  
    // check if a streamable x is a subset of a set y.
    virtual fun \subseteq[C2 with Set[C2,V]] (x:C1, y:C2) = 
    {
      for v in x do
        if not (v \in y) goto bad;
      done
      return true;
  bad:>
      return false;
    }
  
    // subset or equal: variant equality bar
    fun \subseteqq [C2 with Set[C2,V], Streamable[C2,V]] 
      (x:C1, y:C2) => x \subseteq y
    ;
  
    // congruence (equality as sets)
    virtual fun \cong[C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => x \subseteq y and y \subseteq x
    ;
  
    // negated congruence
    fun \ncong[C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => not (x \cong y)
    ;
  
    // proper subset
    virtual fun \subset [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => x \subseteq y and x \ncong y
    ;
  
    // variant proper relations with strke-through on equality bar
    fun \subsetneq [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => x \subset y
    ;
    fun \subsetneqq [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => x \subset y
    ;
  
    // reversed relations, super set
    fun \supset [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => y \subset x
    ;
  
    fun \supseteq [C2 with Set[C2,V], Streamable[C2,V]] 
      (x:C1, y:C2) => y \subseteq x
    ;
  
    fun \supseteqq [C2 with Set[C2,V], Streamable[C2,V]] 
      (x:C1, y:C2) => y \subseteq x
    ;
    // variant proper relations with strke-through on equality bar
    fun \supsetneq [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => x \supset y
    ;
    fun \supsetneqq [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => x \supset y
    ;
  
  
    // negated operators, strike-through
    fun \nsubseteq [C2 with Set[C2,V], Streamable[C2,V]] 
      (x:C1, y:C2) => not (x \subseteq y)
    ;
  
    fun \nsubseteqq [C2 with Set[C2,V], Streamable[C2,V]] 
      (x:C1, y:C2) => not (x \subseteq y)
    ;
  
    // negated reversed operators, strike-through
    fun \nsupseteq [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => not (x \supseteq y)
    ;
  
    fun \nsupseteqq [C2 with Set[C2,V], Streamable[C2,V], Set[C1,V]] 
      (x:C1, y:C2) => not (x \supseteq y)
    ;
  
  }
  
  
Streams
=======

A functional stream is a coinductive data type
dual to a list: it is a function 

   uncons: S -> T * S.
First here is the class based definition of a stream.
It has some problems as do all such definitions:

.. index:: Fstream(class)
.. index:: uncons(fun)
.. code-block:: felix

  //[stream.flx]
  class Fstream[T,S] {
    virtual fun uncons: S -> T * S;
  };
And now, we have a stream example.
It is suprising? An integer is a stream.


.. index:: uncons(fun)
.. code-block:: felix

  //[stream.flx]
  instance Fstream [int,int] {
    fun uncons(x:int) => x, x + 1;
  }

An obvious problem: the stream is ascending.
A descending stream is obvious:
fun uncons(x:int) => x, x - 1
and clearly there are rather a LOT of streams that
can be defined on an integer.

A stream is the dual of a list, some say it is an
infinite list. Here is a stream of optional ints
built from a list of ints.


.. index:: uncons(fun)
.. code-block:: felix

  //[stream.flx]
  instance Fstream [opt[int], list[int]] {
    fun uncons: list[int] -> opt[int] * list[int] =
    | Cons (h,t) => Some h, t
    | #Empty => None[int], Empty[int]
    ;
  }
The option type is a good way to provide a trailing
infinite sequence of values mandated by the definition
of a stream.

This function converts an arbitrary stream
into a generator. This hides the state type
and state value from clients, however the forward
iterator we previously had is now degraded to an
input iterator (where I use iterator in the C++ sense)


.. index:: Stream(class)
.. code-block:: felix

  //[stream.flx]
  class Stream 
  {
  fun make_generator [T,S with Fstream[T,S]] 
    (var state:S) 
  =>
    gen () : T = {
      var v,s = uncons state;
      state = s;
      return v;
    }
  ;

Felix already has an interesting construction
called an iterator, it is a generator function
of type

   1 -> opt[T]
We build such iterator out of a stream of optional values


.. code-block:: felix

  //[stream.flx]
  fun make_iterator [T,S with Fstream[opt[T],S]] 
    (var state:S) 
  =>
    make_generator[opt[T],S] state
  ;

Our definition is bad, because so far there is only
ONE kind of fstream for every type.

What we really want is that, given some uncons function,
we can make a fstream object out of it.

here's our stream object: it has an uncons function
and an initial state value. The uncons function
is called uncons_f to avoid ambiguities

.. code-block:: felix

  //[stream.flx]
  typedef stream[T,S] = ( state:S, uncons_f: S -> T * S );
Now, instantiate it.
The critical thing we're doing is translating
the internal uncons_f function, to one that
returns a stream object

.. index:: uncons(fun)
.. code-block:: felix

  //[stream.flx]
  instance[T,S] Fstream[T, stream[T,S]] {
    fun uncons (x:stream[T,S]) : T * stream[T,S] =>
      let head,tail = x.uncons_f x.state in
      head, (state=tail, uncons_f = x.uncons_f)
    ;
  }
  inherit [T,S] Fstream[T,stream[T,S]];
  }
  open Stream;
  


