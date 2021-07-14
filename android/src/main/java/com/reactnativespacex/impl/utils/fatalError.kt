package com.reactnativespacex.impl.utils

fun fatalError(message: String? = null): Nothing {
    error(message ?: "Fatal Error")
}
