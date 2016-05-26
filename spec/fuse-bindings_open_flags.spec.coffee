[ fs, fuse, child_process ] = [ (require "fs"),(require "fuse-bindings"),(require "child_process") ]
####################################################################################################
describe "Fuse-bindings for Node.js", ->

  it "receive following open flags on Linux", (done) ->

    ################################################################################################


    node_fs_open_flags = 

      "r":    """Open file for reading. An exception occurs if the file does not exist.
              """
      "r+":   """Open file for reading and writing. An exception occurs if the file
              does not exist.
              """
      "rs":   """Open file for reading in synchronous mode. Instructs the operating
              system to bypass the local file system cache. This is primarily useful
              for opening files on NFS mounts as it allows you to skip the
              potentially stale local cache. It has a very real impact on I/O 
              performance so don't use this flag unless you need it. Note that this
              doesn't turn fs.open() into a synchronous blocking call. If that's
              what you want then you should be using fs.openSync().
              """ 
      "rs+":  """Open file for reading and writing, telling the OS to open it
              synchronously. See notes for 'rs' about using this with caution.
              """
      "w":    """Open file for writing. The file is created (if it does not exist) or
              truncated (if it exists).
              """
      "wx":   """Like 'w' but fails if path exists.
              """ 
      "w+":   """Open file for reading and writing. The file is created (if it does not
              exist) or truncated (if it exists).
              """
      "wx":   """Like 'w' but fails if path exists.
              """ 
      "wx+":  """Like 'w+' but fails if path exists.
              """ 
      "a":    """Open file for appending. The file is created if it does not exist.
              """ 
      "ax":   """Like 'a' but fails if path exists.
              """ 
      "a+":   """Open file for reading and appending. The file is created if it
              does not exist.
              """ 
      "ax+":  """Like 'a+' but fails if path exists.
              """

    test_expectancies = ->

      expect(fuse_open_results['/r'  ]).toBe(0b00000000000000001000000000000000)
      expect(fuse_open_results['/r+' ]).toBe(0b00000000000000001000000000000010)
      expect(fuse_open_results['/rs' ]).toBe(0b00000000000000001001000000000000)
      expect(fuse_open_results['/rs+']).toBe(0b00000000000000001001000000000010)
      expect(fuse_open_results['/w'  ]).toBe(0b00000000000000001000000000000001)
      expect(fuse_open_results['/w+' ]).toBe(0b00000000000000001000000000000010)
      expect(fuse_open_results['/a'  ]).toBe(0b00000000000000001000010000000001)
      expect(fuse_open_results['/a+' ]).toBe(0b00000000000000001000010000000010)

      expect(fuse_open_results['/wx' ]).not.toBeDefined()
      expect(fuse_open_results['/wx+']).not.toBeDefined()
      expect(fuse_open_results['/ax' ]).not.toBeDefined()
      expect(fuse_open_results['/ax+']).not.toBeDefined()

      expect(test_results_formatted).toBe(
        """
        # FUSE open flags accordance to Node.js open flags on Linux:

        # r   # Open file for reading. An exception occurs if the file does not exist.
              # (Decimal): 32768 (Octal): 00000100000 (Hexadecimal): 00008000
              # (Binary ): 00000000000000001000000000000000

        # r+  # Open file for reading and writing. An exception occurs if the file
              # does not exist.
              # (Decimal): 32770 (Octal): 00000100002 (Hexadecimal): 00008002
              # (Binary ): 00000000000000001000000000000010

        # rs  # Open file for reading in synchronous mode. Instructs the operating
              # system to bypass the local file system cache. This is primarily useful
              # for opening files on NFS mounts as it allows you to skip the
              # potentially stale local cache. It has a very real impact on I/O 
              # performance so don't use this flag unless you need it. Note that this
              # doesn't turn fs.open() into a synchronous blocking call. If that's
              # what you want then you should be using fs.openSync().
              # (Decimal): 36864 (Octal): 00000110000 (Hexadecimal): 00009000
              # (Binary ): 00000000000000001001000000000000

        # rs+ # Open file for reading and writing, telling the OS to open it
              # synchronously. See notes for 'rs' about using this with caution.
              # (Decimal): 36866 (Octal): 00000110002 (Hexadecimal): 00009002
              # (Binary ): 00000000000000001001000000000010

        # w   # Open file for writing. The file is created (if it does not exist) or
              # truncated (if it exists).
              # (Decimal): 32769 (Octal): 00000100001 (Hexadecimal): 00008001
              # (Binary ): 00000000000000001000000000000001

        # wx  # FUSE.open() is never called

        # w+  # Open file for reading and writing. The file is created (if it does not
              # exist) or truncated (if it exists).
              # (Decimal): 32770 (Octal): 00000100002 (Hexadecimal): 00008002
              # (Binary ): 00000000000000001000000000000010

        # wx+ # FUSE.open() is never called

        # a   # Open file for appending. The file is created if it does not exist.
              # (Decimal): 33793 (Octal): 00000102001 (Hexadecimal): 00008401
              # (Binary ): 00000000000000001000010000000001

        # ax  # FUSE.open() is never called

        # a+  # Open file for reading and appending. The file is created if it
              # does not exist.
              # (Decimal): 33794 (Octal): 00000102002 (Hexadecimal): 00008402
              # (Binary ): 00000000000000001000010000000010

        # ax+ # FUSE.open() is never called
        """
      )
      done()

    debug = false
    fs_open_results = {}
    fuse_open_results = {}
    test_results_formatted = ""

    the_test = ->

      pending_count = Object.keys(node_fs_open_flags).length
      for flags of node_fs_open_flags
        do (flags) ->
          fs.open("./mnt/#{flags}", flags, (err,fd) -> 
            fs_open_results["/" + flags] = arguments
            fs.close(fd) unless err
            if --pending_count is 0
              test_results_formatted = format_test_results(fs_open_results,fuse_open_results)
              child_process.exec 'fusermount -uz ./mnt', ->
                fuse.unmount './mnt', ->
                  console.dir fs_open_results if debug
                  console.dir fuse_open_results if debug
                  console.log '\n"""\n' + test_results_formatted + '\n"""' if debug
                  test_expectancies()
          )

    prepare_test_environment = (cb) ->

      fs.mkdir './mnt', ->
        child_process.exec 'fusermount -uz ./mnt', cb

    start_the_test = ->

      fuse.mount('./mnt',

        init: (cb) ->
          @created_files = []
          cb()

        create: (path, mode, cb) ->
          console.log "create", arguments if debug
          @created_files.push(path)
          cb()

        truncate: (path, size, cb) ->
          console.log "truncate", arguments if debug
          cb()

        readdir: (path, cb) ->
          console.log "readdir", arguments if debug
          switch path
            when '/'
              cb(0, Object.keys(node_fs_open_flags))
            else
              cb(0)

        getattr: (path, cb) ->
          console.log "getattr", arguments if debug
          switch 
            when path is '/'
              cb(
                0, 
                mtime: new Date()
                atime: new Date()
                ctime: new Date()
                size: 100
                mode: 0b0100000111101101
                uid: process.getuid()
                gid: process.getgid()
              )
            when path in @created_files or 
                 path.substr(1) in Object.keys(node_fs_open_flags) and path.indexOf('x') is -1
              cb(
                0,
                mtime: new Date()
                atime: new Date()
                ctime: new Date()
                size: 12
                mode: 0b1000000110100100
                uid: process.getuid()
                gid: process.getgid()
              )
            else
              cb(fuse.ENOENT)

        open: (path, flags, cb) ->
          console.log "open", arguments if debug
          fuse_open_results[path] = flags
          cb(0, 42) # 42 is an fd

        read: (path, fd, buf, len, pos, cb) ->
          console.log "read", arguments if debug
          str = 'hello world\n'.slice(pos)
          return cb(0) if !str
          buf.write(str)
          return cb(str.length)

        , -> the_test()

      )

      process.on 'SIGINT', ->
        fuse.unmount './mnt', -> done()

    int2bin = (int) ->
      bitlen = Math.ceil((~0 >>> 0).toString(2).length)
      return (("0".repeat(bitlen) + Number(int >>> 0).toString(2)).substr(-bitlen))

    int2oct = (int) ->
      bitlen = Math.ceil((~0 >>> 0).toString(2).length / 3)
      return (("0".repeat(bitlen) + Number(int >>> 0).toString(8)).substr(-bitlen))

    int2hex = (int) ->
      bitlen = Math.ceil((~0 >>> 0).toString(2).length / 4)
      return (("0".repeat(bitlen) + Number(int >>> 0).toString(16)).substr(-bitlen))

    format_test_results = (fs_open_results,fuse_open_results) ->

      str = "# FUSE open flags accordance to Node.js open flags on Linux:\n\n"
      for flags, description of node_fs_open_flags
        if (fuse_open_flags = fuse_open_results['/' + flags])?
          str += "# #{(flags + "  ").substr(0,3)} "
          for line, index in description.split('\n')
            str += "      " if index > 0
            str += "# #{line}\n"
          str += "      # (Decimal): #{fuse_open_flags} (Octal): #{int2oct(fuse_open_flags)} (Hexadecimal): #{int2hex(fuse_open_flags)}\n"
          str += "      # (Binary ): #{int2bin(fuse_open_flags)}\n"
        else
          str +=
            """
            # #{(flags + "  ").substr(0,3)} # FUSE.open() is never called
            
            """
        str += "\n"
      return str.trim()

    prepare_test_environment(
      start_the_test
    )


    ################################################################################################
