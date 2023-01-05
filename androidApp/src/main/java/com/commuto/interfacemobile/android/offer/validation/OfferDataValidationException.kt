package com.commuto.interfacemobile.android.offer.validation

/**
 * An [Exception] thrown if a problem is encountered while validating data for an offer.
 *
 * @param desc A description providing information about the context in which the exception was thrown.
 */
class OfferDataValidationException(desc: String): Exception(desc)