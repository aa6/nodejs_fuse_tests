[ fs, fuse, ffi, ref ] = [
  (require "fs"),(require "fuse-bindings"),(require "ffi"),(require "ref")
]  

# Functions enough to implement read-only filesystem:
# - readdir(path,cb)
node_open_modes = 
[
  { mode: 'rs+' , value: 0b00000000000000001001000000000010 }
  { mode: 'rs'  , value: 0b00000000000000001001000000000000 }
  { mode: 'a+'  , value: 0b00000000000000001000010000000010 }
  { mode: 'a'   , value: 0b00000000000000001000010000000001 }
  { mode: 'r+'  , value: 0b00000000000000001000000000000010 } # w+ is unsuitable
  { mode: 'w'   , value: 0b00000000000000001000000000000001 }
  { mode: 'r'   , value: 0b00000000000000001000000000000000 }
]

module.exports = ({
  root
}) ->

  fds = { counter: 0 }
  root = root.replace(/\/+$/,"") # Ensure there would be no trailing slash.

  init: (cb) ->
    #console.log "init", arguments
    cb()

  getattr: (path, cb) ->
    #console.log "getattr", arguments
    fs.lstat (root + path), (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  readdir: (path, cb) ->
    # console.log "readdir", arguments
    fs.readdir (root + path), (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  create: (path, mode, cb) ->
    # console.log "create", arguments
    fs.open root + path, "w", (err, result_fd) ->
      fs.fchmod result_fd, mode, ->
        fds[return_fd = ++fds.counter] = result_fd
        cb(0,return_fd)

  open: (path, flags, cb) ->
    # console.log "open", arguments
    mode = do -> for node_mode in node_open_modes
      return node_mode.mode if (flags & node_mode.value) is node_mode.value
    cb(fuse.ENOSYS) unless mode?
    fs.open root + path, mode, (err, result_fd) ->
      fds[return_fd = ++fds.counter] = result_fd
      switch
        when !err
          cb(0,return_fd)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  write: (path, fd, buffer, length, position, cb) ->
    # console.log "write", arguments
    # console.log "fds fd", fds[fd]
    fs.write fds[fd], buffer, 0, length, position, (err, written, buffer) ->
      switch
        when !err
          cb(written)
        else
          cb(0)

  read: (path, fd, buf, len, pos, cb) ->
    #console.log "read", arguments
    fs.read fds[fd], buf, 0, len, pos, (err, bytes_read, buf) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  fsync: (path, fd, datasync, cb) ->
    # console.log "fsync", arguments
    fs.fsync fds[fd], (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  truncate: (path, len, cb) ->
    #console.log "truncate", arguments
    fs.truncate root + path, len, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  ftruncate: (path, fd, len, cb) ->
    #console.log "ftruncate", arguments
    fs.ftruncate fds[fd], len, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  unlink: (path, cb) ->
    # console.log "unlink", arguments
    fs.unlink root + path, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err    

  mkdir: (path, mode, cb) ->
    # console.log "mkdir", arguments
    fs.mkdir root + path, mode, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  
          
  rmdir: (path, cb) ->
    # console.log "rmdir", arguments
    fs.rmdir root + path, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  

  chown: (path, uid, gid, cb) ->
    fs.chown root + path, uid, gid, (err) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  chmod: (path, mode, cb) ->
    # console.log "chmod", arguments
    fs.chmod root + path, mode, (err) ->
      switch
        when !err
          cb(0)
        else
          cb(fuse[err.code])

  rename: (src, dest, cb) ->
    # console.log "rename", arguments
    fs.rename root + src, root + dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  symlink: (src, dest, cb) ->
    #console.log "symlink", arguments
    fs.symlink src, root + dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  

  readlink: (path, cb) ->
    #console.log "readlink", arguments
    fs.readlink root + path, (err, result) ->
      #console.log "readlink-res", result
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  utimens: (path, atime, mtime, cb) ->
    # console.log "utimens", arguments
    fs.utimes root + path, atime, mtime, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  release: (path, fd, cb) ->
    # console.log "release", arguments
    fs.close fds[fd], ->
      cb(0)

  statfs: (path, cb) ->
    #console.log "statfs", arguments
    fetch_disk_info root, (err, info) ->
      cb(
        0,
        bsize:    info.f_bsize
        frsize:   info.f_frsize
        blocks:   info.f_blocks
        bfree:    info.f_bfree
        bavail:   info.f_bavail
        files:    info.f_files
        ffree:    info.f_ffree
        favail:   info.f_favail
        fsid:     info.f_fsid
        flag:     info.f_flag
        namemax:  info.f_namemax
      )

  ##########################################

  # # Creates hard link.
  # link: (src, dest, cb) ->
  #   # console.log "link", arguments
  #   fs.link src, dest, (err) ->
  #     switch
  #       when !err
  #         cb(0)
  #       when fuse[err.code]?
  #         cb(fuse[err.code])
  #       else
  #         throw err    


fetch_disk_info = do -> 

  Struct = require "ref-struct"
  ArrayType = require "ref-array"
  statvfs_t = Struct(
    f_bsize:    ref.types.ulong                 # fundamental file system block size
    f_frsize:   ref.types.ulong                 # fragment size
    f_blocks:   ref.types.ulong                 # total blocks of f_frsize on fs
    f_bfree:    ref.types.ulong                 # total free blocks of f_frsize
    f_bavail:   ref.types.ulong                 # free blocks avail to non-superuser
    f_files:    ref.types.ulong                 # total file nodes (inodes)
    f_ffree:    ref.types.ulong                 # total free file nodes
    f_favail:   ref.types.ulong                 # free nodes avail to non-superuser
    f_fsid:     ref.types.ulong                 # file system id (dev for now)
    f_basetype: ArrayType(ref.types.char, 16)   # target fs type name, null-terminated
    f_flag:     ref.types.ulong                 # bit-mask of flags
    f_namemax:  ref.types.ulong                 # maximum file name length
    f_fstr:     ArrayType(ref.types.char, 32)   # filesystem-specific string
    f_filler:   ArrayType(ref.types.ulong, 16)  # reserved for future expansion
  )
  DiskApi = ffi.Library(null, statvfs: ['int',['string',ref.refType(statvfs_t)]])

  return (drive, callback) ->
    statvfs = new statvfs_t()
    returnCode = DiskApi.statvfs(drive, statvfs.ref())
    if returnCode
      callback(returnCode, undefined)
    else 
      callback(undefined, statvfs)