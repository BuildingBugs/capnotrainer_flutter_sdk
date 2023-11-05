
This package provides an easy way to integrate CapnoTrainer GO device with your Flutter app. The basic idea is to use *flutter_blue_plus* package, scan for GO devices and pass the *BluetoothDevice* object and a callback function to the CapnoTrainer connect method. Once done, call disconnect on the same CapnoTrainer object. The data is received on callback handler. 

## Features

1) Easier way to connect to GO device.
2) Different data is already parsed and ready to be further processed or present. 
3) BLE handling is done by the package so no need to worry about managing it separately. 

## Getting started

See the examples folder. 

*P.S: The example is tested on Android phone. However, it will work for iOS as well as long as relevant permissions are handled under ios folder.*

## Usage

Full example is available in example folder

