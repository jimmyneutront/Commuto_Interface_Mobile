package com.example.commuto_interface_mobile

class Greeting {
    fun greeting(): String {
        return "Hello, ${Platform().platform}!"
    }
}