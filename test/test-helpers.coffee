Kefir = require("../dist/kefir")
sinon = require('sinon')


exports.Kefir = Kefir


logItem = (event) ->
  if event.type == 'value'
    if event.current
      {current: event.value}
    else
      event.value
  else
    if event.current
      '<end:current>'
    else
      '<end>'

exports.watch = (obs) ->
  log = []
  obs.onAny (event) ->
    log.push(logItem event)
  log

exports.watchWithTime = (obs) ->
  startTime = new Date()
  log = []
  obs.onAny (event) ->
    log.push([(new Date() - startTime), (logItem event)])
  log


exports.send = (obs, events) ->
  for event in events
    if event == '<end>'
      obs._send('end')
    else
      obs._send('value', event)
  obs


_activateHelper = ->

exports.activate = (obs) ->
  obs.onEnd _activateHelper
  obs

exports.deactivate = (obs) ->
  obs.offEnd _activateHelper
  obs


exports.prop = ->
  new Kefir.Property()

exports.stream = ->
  new Kefir.Stream()

exports.withFakeTime = (cb) ->
  clock = sinon.useFakeTimers(10000)
  cb(  (t) -> clock.tick(t)  )
  clock.restore()


exports.inBrowser = window? and document?

exports.withDOM = (cb) ->
  div = document.createElement('div')
  document.body.appendChild(div)
  cb(div)
  document.body.removeChild(div)



getCurrent = (prop) ->
  val = getCurrent.NOTHING
  save = (x, isCurrent) ->
    if isCurrent
      val = x
  prop.on 'value', save
  prop.off 'value', save
  val
getCurrent.NOTHING = ['<getCurrent.NOTHING>']




beforeEach ->
  @addMatchers {
    toBeProperty: ->
      @message = -> "Expected #{@actual.toString()} to be instance of Property"
      @actual instanceof Kefir.Property
    toBeStream: ->
      @message = -> "Expected #{@actual.toString()} to be instance of Stream"
      @actual instanceof Kefir.Stream

    toBeActive: -> @actual._active

    toEmit: (expectedLog, cb) ->
      log = exports.watch(@actual)
      cb?()
      @message = -> "Expected to emit #{jasmine.pp(expectedLog)}, actually emitted #{jasmine.pp(log)}"
      @env.equals_(expectedLog, log)

    toEmitInTime: (expectedLog, cb, timeLimit = 10000) ->
      log = null
      exports.withFakeTime (tick) =>
        log = exports.watchWithTime(@actual)
        cb?(tick)
        tick(timeLimit)
      @message = -> "Expected to emit #{jasmine.pp(expectedLog)}, actually emitted #{jasmine.pp(log)}"
      @env.equals_(expectedLog, log)

    toHasNoCurrent: -> getCurrent(@actual) == getCurrent.NOTHING
    toHasCurrent: (x) -> getCurrent(@actual) == x
    toHasEqualCurrent: (x) -> @env.equals_(x, getCurrent(@actual))

    toActivate: (obss...) ->
      conditions = []
      conditions.push (!obs._active for obs in obss)...
      exports.activate(@actual)
      conditions.push (obs._active for obs in obss)...
      exports.deactivate(@actual)
      conditions.push (!obs._active for obs in obss)...
      exports.activate(@actual)
      conditions.push (obs._active for obs in obss)...
      exports.deactivate(@actual)
      conditions.push (!obs._active for obs in obss)...
      allTrue = true
      for condition in conditions
        allTrue = allTrue && condition
      @message = ->
        obssString = (obs.toString() for obs in obss).join(', ')
        "Expected #{@actual.toString()} to activate #{obssString} (results: #{jasmine.pp(conditions)})"
      allTrue
  }

