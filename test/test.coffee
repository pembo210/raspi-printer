assert = require("chai").assert
sinon  = require("sinon")
nock   = require("nock")

URL  = require("url")

print = require("../lib/print-server.js")

describe "PrintServer", ->

  describe "creation", ->
    it "should be configured for a particular URL", ->
      ps = new print.PrintServer('http://fake.com/abc123', 'A2-TYPE')
      assert.equal(URL.format(ps.printUrl), 'http://fake.com/abc123')

    it "requires a print server", ->
      createNewServerWithError = () -> 
        new print.PrintServer()
      assert.throw(createNewServerWithError)

  describe "polling", ->

    beforeEach ->
      this.ps = new print.PrintServer('http://fake.com/abc123', 'printer-type')
      this.clock = sinon.useFakeTimers()

    afterEach ->
      this.ps = null
      this.clock.restore()

    it "should have a default poll interval", ->
      assert.equal(this.ps.pollingIntervalInSecs, 10)

    it "should be start/stoppable polling", ->
      assert.isFalse this.ps.isPolling()
      this.ps.startPolling()
      assert.isTrue  this.ps.isPolling()
      this.ps.stopPolling()
      assert.isFalse this.ps.isPolling()

    it "should poll according to interval", (done) ->
      server = nock('http://fake.com').get('/abc123').reply(200)
      hasPolledFired = false
      this.ps.on('polled', () -> 
        assert(true, "event should have fired")
        done()
      )
      this.ps.startPolling()
      this.clock.tick(9999)
      assert.isFalse(hasPolledFired, "event should not have fired")
      this.clock.tick(1)

    it "shouldn't stop polling on error", (done) ->
      self = this

      server = nock('http://fake.com')
                .get('/abc123').reply(500, "The document body")
                .get('/abc123').reply(500, "The document body")

      pollFiredCounter = 1

      self.ps.on('polled', () -> 
        done() if pollFiredCounter == 2
        pollFiredCounter++
        self.ps.poll()
      )

      self.ps.poll()

    it "should HTTP GET server", ->
      server = nock('http://fake.com')
                .get('/abc123')
                .reply(200)
      this.ps.poll()
      server.done()

    it "should identify itself", ->
      server = nock('http://fake.com')
                .get('/abc123')
                .matchHeader('Accept', 'application/vnd.freerange.printer.A2-raw')
                .reply(200)

      ps = new print.PrintServer('http://fake.com/abc123', 'A2-raw')
      ps.poll()
      server.done()

  describe "on response", (done) ->
    beforeEach ->
      this.ps = new print.PrintServer('http://fake.com/abc123', 'printer-type')

    afterEach ->
      this.ps = null

    it "should emit requestFailed on non-200 response", (done) ->
      server = nock('http://fake.com')
                .get('/abc123')
                .reply(500, "An error", { "Content-Length" : 1024 })

      documentReceivedCallback = () ->
        #assert.equal(doc, "The document body", "document should be part of event")
        done()

      this.ps.on("requestFailed", documentReceivedCallback)
      this.ps.poll()

    it "should use content length to detect document", () ->
      assert.isFalse(this.ps.responseHasDocument({ headers: {"content-length": 0} }))
      assert.isTrue(this.ps.responseHasDocument({ headers: {"content-length": 1023} }))

    it "should emit a documentReceived event", (done) ->
      server = nock('http://fake.com')
                .get('/abc123')
                .reply(200, "The document body", { "Content-Length" : 1024 })

      documentReceivedCallback = (doc) ->
        assert.equal(doc, "The document body", "document should be part of event")
        done()

      this.ps.on("documentReceived", documentReceivedCallback)
      this.ps.poll()


