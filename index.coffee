Traverse = require 'traverse'

###*
* @helper daisy
* @description - serial async helper
###

daisy =(args)->
  process.nextTick args.next = ->
    if fn = args.shift() then !!fn args


slowDaisy =(args)->
  process.nextTick args.next = ->
    if fn = args.shift() then process.nextTick fn.bind null, args...


module.exports = class Scrubber

  @use =(middleware...)->
    unless @stack? then @stack = middleware
    else @stack = @stack.concat middleware


  ###*
  * @constructor Scrubber
  * @description - initializes the Scrubber instance.
  ###

  constructor:(middleware...)->
    if 'function' is typeof middleware[0]
      @stack = middleware
    else
      [@stack] = middleware


  ###*
  * @method Scrubber#scrub
  * @description - traverses an arbitrary JS object and applies the middleware
  *  stack, serially, to each node encountered during the walk.
  ###

  scrub:(obj, callback)->
    scrubber = this
    queue = []
    steps = @stack.map (fn)->
      switch fn.length
        # async wrapper for any synchronous functions.
        when 0, 1
          (cursor, next)->
            fn.call @, cursor
            next()
        when 2 then fn
        # throw early, throw often
        else throw new TypeError (
          'Scrubber requires a callback with 1- or 2-arity. '+
          "User provided a #{fn.length}-arity callback"
        )
    nodes = []
    @out = new Traverse(obj).map ->
      cursor = this
      steps.forEach (step)->
        queue.push -> step.call scrubber, cursor, -> queue.next()
      return
    queue.push ->
      callback.call scrubber
    if seemsTooComplex queue.length, 4
      slowDaisy queue
    else
      daisy queue


  seemsTooComplex =do->
    maxStackSize = try
      i = 0
      do f =-> i++; f()
    catch e then i
    (length, weight)->
      guess = length * weight
      guess > maxStackSize


  ###*
  * @method Scrubber#forEach
  * @method Scrubber#indexOfå
  * @method Scrubber#join
  * @method Scrubber#pop
  * @method Scrubber#reverse
  * @method Scrubber#shift
  * @method Scrubber#sort
  * @method Scrubber#splice
  * @method Scrubber#unshift
  * @method Scrubber#push
  * @description - proxies for the native Array methods; they apply themselves
  *   to the middleware stack
  ###

  [
    'forEach','indexOf','join','pop','reverse'
    'shift','sort','splice','unshift','push'
  ]
  .forEach (method)=> @::[method] =(rest...)-> @stack[method].apply @stack, rest


  ###*
  * @method Scrubber#use
  * @description alias for push.
  ###

  @::use = @::push