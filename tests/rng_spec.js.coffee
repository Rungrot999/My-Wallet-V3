proxyquire = require('proxyquireify')(require);

RNG   = proxyquire('../src/rng', {})

describe "RNG", ->
  serverBuffer = new Buffer(
    "0000000000000000000000000000000000000000000000000000000000000010",
    "hex"
  )

  zerosServerBuffer = new Buffer(
    "0000000000000000000000000000000000000000000000000000000000000000",
    "hex"
  )

  shortServerBuffer = new Buffer(
    "0000000000000000000000000000000001",
    "hex"
  )

  xorBuffer = new Buffer(
    "0000000000000000000000000000000000000000000000000000000000000011",
    "hex"
  )

  xorFailingServerBuffer = new Buffer(
    "0000000000000000000000000000000000000000000000000000000000000001",
    "hex"
  )

  describe ".xor()", ->

    it "should be an xor operation", ->
      A = new Buffer('a123456c', 'hex')
      B = new Buffer('ff0123cd', 'hex')
      R = '5e2266a1'
      expect(RNG.xor(A,B).toString('hex')).toEqual(R)

    it "should throw when buffers are of different length", ->
      A = new Buffer('a123'    , 'hex')
      B = new Buffer('ff0123cd', 'hex')
      spy = jasmine.createSpy('after xor')
      try
        RNG.xor(A, B)
        spy()
      catch error
        expect(error.message).toEqual('Expected arguments to have equal length')
      expect(spy).not.toHaveBeenCalled()

  describe ".run()", ->
    browser = {
      lastBit: 1
    }

    beforeEach ->
      spyOn(window.crypto, "getRandomValues").and.callFake((array) -> array[31] = browser.lastBit)
      spyOn(console, "log").and.callFake(() -> )

    it "should ask for 32 bytes from the server", ->
      spyOn(RNG, "getServerEntropy").and.callFake(
        (bytes) ->
          expect(bytes).toEqual(32)
          serverBuffer
      )
      RNG.run()

    it "returns the mixed entropy", ->
      spyOn(RNG, "getServerEntropy").and.callFake(
        (bytes) ->
          serverBuffer
      )

      expect(RNG.run().toString("hex")).toEqual(xorBuffer.toString("hex"))

    it "fails if server data is all zeros", ->
      spyOn(RNG, "getServerEntropy").and.callFake(
        (bytes) ->
          zerosServerBuffer
      )
      expect(() -> RNG.run()).toThrow()

    it "fails if browser data is all zeros", ->
      spyOn(RNG, "getServerEntropy").and.callFake(
        (bytes) ->
          serverBuffer
      )
      browser.lastBit = 0
      expect(() -> RNG.run()).toThrow()
      browser.lastBit = 1

    it "fails if server data has the wrong length", ->
      spyOn(RNG, "getServerEntropy").and.callFake(
        (bytes) ->
          shortServerBuffer
      )
      expect(() -> RNG.run()).toThrow()

    it "fails if combined entropy is all zeros", ->
      spyOn(RNG, "getServerEntropy").and.callFake(
        (bytes) ->
          xorFailingServerBuffer
      )
      expect(() -> RNG.run()).toThrow()

  describe ".getServerEntropy()", ->
    mock =
      responseText: "0000000000000000000000000000000000000000000000000000000000000010"

    request =
      open: () ->
      setRequestHeader: () ->
      send: () ->
        this.status = 200
        this.responseText = mock.responseText

    beforeEach ->
      spyOn(window, "XMLHttpRequest").and.returnValue request
      spyOn(request, "open").and.callThrough()

    it "makes a GET request to the backend", ->
      RNG.getServerEntropy(32)
      expect(request.open).toHaveBeenCalled()
      expect(request.open.calls.argsFor(0)[0]).toEqual("GET")
      expect(request.open.calls.argsFor(0)[1]).toContain("api.blockchain.info")

    it "returns a buffer is successful", ->
      res = RNG.getServerEntropy(32)
      expect(Buffer.isBuffer(res)).toBeTruthy()

    it "throws an exception if result is not hex", ->
      mock.responseText = "This page was not found"
      expect(() -> RNG.getServerEntropy(32)).toThrow()

    it "throws an exception if result is the wrong length", ->
      mock.responseText = "000001"
      expect(() -> RNG.getServerEntropy(3)).not.toThrow()
      expect(() -> RNG.getServerEntropy(32)).toThrow()
