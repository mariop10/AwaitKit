/*
 * AwaitKit
 *
 * Copyright 2016-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

import Foundation
import PromiseKit
import Dispatch

extension Extension where Base: DispatchQueue {
  /**
   Awaits that the given closure finished on the receiver and returns its value or throws an error if the closure failed.

   - parameter body: The closure that is executed on the receiver.
   - throws: The error sent by the closure.
   - returns: The value of the closure when it is done.
   - seeAlso: await(promise:)
   */
  @discardableResult
  public final func await<T>(_ body: @escaping () throws -> T) throws -> T {
    let promise = self.base.async(.promise, execute: body)

    return try await(promise)
  }

  /**
   Awaits that the given promise resolved on the receiver and returns its value or throws an error if the promise failed.

   - parameter promise: The promise to resolve.
   - throws: The error produced when the promise is rejected or when the queues are the same.
   - returns: The value of the promise when it is resolved.
   */
  @discardableResult
  public final func await<T>(_ promise: Promise<T>) throws -> T {
    guard self.base.label != DispatchQueue.main.label else {
      throw NSError(domain: "com.yannickloriot.awaitkit", code: 0, userInfo: [
        NSLocalizedDescriptionKey: "Operation was aborted.",
        NSLocalizedFailureReasonErrorKey: "The current and target queues are the same."
        ])
    }

    var result: T?
    var error: Swift.Error?

    let group = DispatchGroup()
    group.enter()

    promise
      .then(on: self.base) { value -> Promise<Void> in
        result = value

        group.leave()

        return Promise()
      }
      .catch(on: self.base, policy: .allErrors) { err in
        error = err

        group.leave()
      }

    group.wait()

    guard let unwrappedResult = result else {
      throw error!
    }

    return unwrappedResult
  }

  /**
   Awaits that the given guarantee resolved on the receiver and returns its value or throws an error if the current and target queues are the same.

   - parameter guarantee: The guarantee to resolve.
   - throws: when the queues are the same.
   - returns: The value of the guarantee when it is resolved.
   */
  @discardableResult
  public final func await<T>(_ guarantee: Guarantee<T>) throws -> T {
    guard self.base.label != DispatchQueue.main.label else {
      throw NSError(domain: "com.yannickloriot.awaitkit", code: 0, userInfo: [
        NSLocalizedDescriptionKey: "Operation was aborted.",
        NSLocalizedFailureReasonErrorKey: "The current and target queues are the same."
        ])
    }

    var result: T?

    let semaphore = DispatchSemaphore(value: 0)

    guarantee
      .then(on: self.base) { value -> Guarantee<Void> in
        result = value

        semaphore.signal()

        return Guarantee()
      }

    _ = semaphore.wait(timeout: .distantFuture)

    return result!
  }
}
