//
//  ViewState.swift
//  RoundUpSaver
//
//  Created by Elliott D'Alvarez on 29/09/2026.
//

enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}
