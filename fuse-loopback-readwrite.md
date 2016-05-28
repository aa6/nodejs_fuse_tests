`fuse-loopback-readwrite` is a moderate-featured loopback filesystem implementation for a Node.js `fuse-bindings` package. It consists of 20 functions.
#### init(cb)
Called prior to all other functions on filesystem initialization. It is called only one time per each mount and always accepts only one input argument.

Parameters:  
`cb` Callback to call after the function done it's work.

#### readdir(path, cb)