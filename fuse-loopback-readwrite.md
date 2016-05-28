`fuse-loopback-readwrite` is a moderate-featured loopback filesystem implementation for a Node.js `fuse-bindings` package. It consists of 20 functions.
#### init(cb)
Called on filesystem initialization, prior to all other functions. Called only one time per each mount. Always accepts only one input argument.

Parameters:  
`cb` Callback to call after the function done it's work.

Return:  
Init doesn't return any values and would NOT raise any errors or exceptions if you'll pass an error code to the `cb` as an argument.

#### readdir(path, cb)