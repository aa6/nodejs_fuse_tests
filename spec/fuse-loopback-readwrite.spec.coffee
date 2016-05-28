[ fs, fuse, path, child_process, loopbackfs, domain ] = [ 
  (require "fs-extra"),(require "fuse-bindings"),(require "path"),(require "child_process"),
  (require "../fuse-loopback-readwrite.coffee"),(require "domain")
]
####################################################################################################
####################################################################################################
describe "Fuse-bindings loopback read-write filesystem implementation", ->
  time = {}
  testname = path.basename(path.basename(__filename,".coffee"),".spec")
  looproot = "data/#{testname}-looproot"
  mountpoint = "data/#{testname}-mountpoint"
  expectations =
    "init always accept only 1 argument"                                      : undefined
    "init is called only 1 time per each mount"                               : undefined
    "init would generate a FUSE error if pass to `cb` anything but 0"         : undefined
    "readdir accepts 2 arguments"                                             : undefined
    "readdir is not called when entry doesn't exists"                         : undefined
    "readdir `path` argument always starts with a slash"                      : undefined
    "fuse implementation functions are not integrated by the `this` context"  : undefined
  callhistory = []
  test_counter = 0
  zones_counter = 0
  fs.emptyDirSync(looproot)
  fs.emptyDirSync(mountpoint)
  loopbackfs_instance = loopbackfs(root:looproot)
  loopbackfs_debug_instance = 

    init: (cb) ->
      zone = domain.create()
      zone.number = zones_counter++
      callhistory.push(
        fn: "init"
        env: { cb: cb }
        name: "fuse call"
        this: @
        date: new Date()
        zone: zone
        args: arguments
        testnum: test_counter
      )
      zone.run =>
        loopbackfs_instance.init(cb)

    readdir: (path, cb) ->
      zone = domain.create()
      zone.number = zones_counter++
      callhistory.push(
        fn: "readdir"
        env: { path: path, cb: cb }
        name: "fuse call"
        this: @
        date: new Date()
        zone: zone
        args: arguments
        testnum: test_counter
      )
      zone.run =>
        loopbackfs_instance.readdir path, (err, files) ->
          callhistory.push(
            fn: "readdir"
            env: { path: path, cb: cb, err: err, files: files }
            name: "fuse call result"
            this: @
            date: new Date()
            zone: zone
            args: arguments
            testnum: test_counter
          )
          cb(err,files)

  # Copy undeclared functions to the debug instance.
  for key, val of loopbackfs_instance
    unless loopbackfs_debug_instance[key]?
      loopbackfs_debug_instance[key] = val
  
  # Mount function with some tests attached to it.
  mount_loopbackfs_debug_instance = (done) ->
    fuse.mount mountpoint, loopbackfs_debug_instance, (err) ->
      expect(arguments.length).toBe(1)
      expect(err).toBe(undefined)
      setTimeout(done,100)

  # Umount function with some tests attached to it.
  umount_loopbackfs_debug_instance = (done) ->
    setTimeout(
      ->
        child_process.exec "fusermount -u #{mountpoint}", (err,stdout,stderr) ->
          expect(arguments.length).toBe(3)
          expect(err).toBe(null)
          expect(stdout).toBe("")
          expect(stderr).toBe("")
          child_process.exec "fusermount -u #{mountpoint}", (err,stdout,stderr) ->
            expect(arguments.length).toBe(3)
            expect(err instanceof Error).toBe(true)
            expect(stdout).toBe("")
            expect(stderr.indexOf("not found in /etc/mtab")).not.toBe(-1)
            done()
      100
    )

  # Increase test counter to separate tests from each other
  beforeEach -> test_counter++

  # Mount filesystem before each test.
  beforeEach (done) -> mount_loopbackfs_debug_instance(done)

  # Umount filesystem after each test.
  afterEach (done) -> umount_loopbackfs_debug_instance(done)

####################################################################################################
####################################################################################################
  it "mounts and unmounts", (done) ->

    done() # Everything for this test happens in `beforeEach` and `afterEach` calls.

####################################################################################################
####################################################################################################
  it "performs readdir calls without throwing unexpected errors", (done) ->

    fs.mkdirSync(looproot + "/readdirtest")
    fs.mkdirSync(looproot + "/readdirtest/dir1")
    time.before_readdirtest_ls = new Date()
    child_process.exec "ls #{mountpoint}/readdirtest", ->
      time.after_readdirtest_ls = new Date()
      child_process.exec "ls #{mountpoint}/nonexistantdir", ->
        verify_expectations()

    verify_expectations = ->
      expect(
        callhistory.some (event) ->
          event.fn is "readdir" &&
          event.testnum is test_counter
      ).toBe(true)
      done()

####################################################################################################
####################################################################################################
  it "meets all the expectations precisely", ->

    #                                : undefined
    # "init would generate a FUSE error if pass to `cb` anything but 0"         : undefined
    # "readdir accepts 2 arguments"                                             : undefined
    # "readdir is not called when entry doesn't exists"                         : undefined
    # "readdir `path` argument always starts with a slash"                      : undefined
    # "fuse implementation functions are not integrated by the `this` context"  : undefined

    expectations["init always accept only 1 argument"] = callhistory.every (call) ->
      switch
        when call.fn is "init" && call.name is "fuse call"
          return call.args.length is 1
        else
          return true

    init_calls = {}
    expectations["init is called only 1 time per each mount"] = callhistory.every (call) ->
      switch
        when call.fn is "init" && call.name is "fuse call"
          if init_calls[call.testnum]?
            return false
          else
            return (init_calls[call.testnum] = true)
        else
          return true

    expectations["readdir `path` argument always starts with a slash"] = callhistory.every (call) ->
      switch
        when call.fn is "readdir" && call.name is "fuse call"
          return call.env.path[0] is "/"
        else
          return true

    # expectations["readdir accepts 2 arguments"] = eventshistory.some (event) ->
    #   time.before_readdirtest_ls < event.date < time.after_readdirtest_ls  &&
    #   event.path is "/readdirtest" &&
    #   event.name is "fuse call" &&
    #   event.fn is "readdir" &&
    #   event.arguments.length is 2

    # # "fuse implementation functions are not integrated by the `this` context"
    # if @ is global and expectations["fuse implementation functions are not integrated by the `this` context"] isnt false
    #   expectations["fuse implementation functions are not integrated by the `this` context"] = true
    # else
    #   expectations["fuse implementation functions are not integrated by the `this` context"] = false

    # # "init is called only 1 time per each mount"
    # expectations["init is called only 1 time per each mount"] = 
    #   if expectations["init is called only 1 time per each mount"]? then false else true
    # expectations["readdir is not called when entry doesn't exists"] = !callhistory.some (event) ->
    #   event.fn is "readdir" &&
    #   event.test is test_counter &&
    #   event.path is "/nonexistantdir"

    for key, val of expectations
      expect([key,val]).toEqual([key,true])

####################################################################################################
####################################################################################################
  it "matches the preformatted description", ->

    preformatted_description = ""

    generate_formatted_description = ->
      """
      `fuse-loopback-readwrite` is a moderate-featured loopback filesystem implementation for a \
      Node.js `fuse-bindings` package. It consists of #{Object.keys(loopbackfs_instance).length} \
      functions.
      #### init(cb)
      Called prior to all other functions on filesystem initialization. #{if expectations["init \
      is called only 1 time per each mount"] then "It is called only one time per each mount" else \
      "UNEXPECTED VALUE"} #{if expectations["init always accept only 1 argument"] then "and \
      always accepts only one input argument." else "UNEXPECTED VALUE"}

      @param `cb` Callback to call after the function done it's work.
      
      #### readdir(path, cb)
      """

    console.log generate_formatted_description()
    #console.dir Object.keys(loopbackfs_instance)