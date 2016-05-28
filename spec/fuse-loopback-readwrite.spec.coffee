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
    "init would NOT generate a FUSE error if pass to `cb` anything but 0"     : undefined
    "readdir always accepts only 2 arguments"                                 : undefined
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

  # Some tests require custom debug instance, some require none. Thus this is used when necessary.
  default_mount_wrapper = (done,middleware) ->
    mount_loopbackfs_debug_instance ->
      middleware ->
        umount_loopbackfs_debug_instance(done)

  # Increase test counter to separate tests from each other
  beforeEach -> test_counter++

####################################################################################################
####################################################################################################
  it "mounts and unmounts", (done) -> default_mount_wrapper done, (done) ->

    done() # Everything for this test happens in `default_mount_wrapper`.

####################################################################################################
####################################################################################################
  it "performs readdir without unexpected errors", (done) -> default_mount_wrapper done, (done) ->

    fs.mkdirSync(looproot + "/readdirtest")
    fs.mkdirSync(looproot + "/readdirtest/dir1")
    child_process.exec "ls #{mountpoint}/readdirtest", ->
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
  it "performs custom init test without unexpected errors", (done) ->

    try

      custom_init_was_called = false
      default_init = loopbackfs_debug_instance.init
      loopbackfs_debug_instance.init = (cb) ->
        loopbackfs_instance.init ->
          custom_init_was_called = true
          cb(fuse.ENODEV)

      mount_loopbackfs_debug_instance -> umount_loopbackfs_debug_instance ->
        loopbackfs_debug_instance.init = default_init
        verify_expectations()

      verify_expectations = ->
        expect(custom_init_was_called).toBe(true)
        expectations["init would NOT generate a FUSE error if pass to `cb` anything but 0"] = true
        done()

    catch err

      expectations["init would NOT generate a FUSE error if pass to `cb` anything but 0"] = false
      done()

####################################################################################################
####################################################################################################
  it "meets all the expectations precisely", ->

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

    expectations["readdir always accepts only 2 arguments"] = callhistory.every (call) ->
      switch
        when call.fn is "readdir" && call.name is "fuse call"
          return call.args.length is 2
        else
          return true

    expectations["readdir is not called when entry doesn't exists"] = callhistory.every (call) ->
      switch
        when call.fn is "readdir" && call.name is "fuse call"
          return call.env.path isnt "/nonexistantdir"
        else
          return true

    expectations["fuse implementation functions are not integrated by the `this` context"] = callhistory.every (call) ->
      switch
        when call.name is "fuse call"
          return call.this is global
        else
          return true

    for key, val of expectations
      expect([key,val]).toEqual([key,true])

####################################################################################################
####################################################################################################
  it "matches the preformatted description", ->

    preformatted_description = fs.readFileSync("#{testname}.md").toString()
    ERRSTR = "UNEXPECTED VALUE"

    generate_formatted_description = ->
      """
      [`fuse-loopback-readwrite`](/#{testname}.coffee) is a moderate-featured loopback filesystem \
      linux-only implementation for a Node.js [`fuse-bindings`](https://github.com/mafintosh/fuse-\
      bindings) package. It consists of #{Object.keys(loopbackfs_instance).length} functions. #{if \
      expectations["fuse implementation functions are not integrated by the `this` context"] then \
      "The functions are not binded upon mounting into some class instance and `this` by default \
      points to a higher context, usually to `global`." else ERRSTR}

      This text is backed and generated by [the test in `spec` folder](/spec/#{testname}.spec.coffee)

      ### init(cb)
      Called on filesystem initialization, prior to all other functions. #{if expectations["init \
      is called only 1 time per each mount"] then "Called only one time per each mount." else ERRSTR} \
      #{if expectations["init always accept only 1 argument"] then "Always accepts only one \
      input argument." else ERRSTR}

      **Parameters:**  
      `cb` Callback to call after the function done it's work.

      **Return:**  
      Init doesn't return any values and #{if expectations["init would NOT generate a FUSE error \
      if pass to `cb` anything but 0"] then "would NOT raise any errors or exceptions if you'll \
      pass an error code to the `cb` as an argument." else ERRSTR}
      
      ### readdir(path, cb)
      Called when a directory is being listed. #{if expectations["readdir is not called when entry \
      doesn't exists"] then "Readdir is not called if the `path` entry wasn't listed by parent \
      directory readdir call (if the entry doesn't exists)." else ERRSTR} #{if expectations["\
      readdir always accepts only 2 arguments"] then "Always accepts only two input arguments." \
      else ERRSTR}

      **Parameters:**  
      `path` Path to a file within the FUSE filesystem. #{if expectations["readdir `path` argument \
      always starts with a slash"] then "Path is always starts with a directory separator (slash)." \
      else ERRSTR}  
      `cb` Callback to call after the function done it's work.

      **Return:**  
      Returns values by `cb(error_code, entries_array)` callback. `entries_array` is a list of \
      files and directories which requested `path` contains.
      """

    if process.env.NODE_ENV is "debug"
      console.dir preformatted_description
      console.dir generate_formatted_description()
      console.log "---------"
      console.log generate_formatted_description()

    expect(
      generate_formatted_description() is preformatted_description
    ).toBe(true)