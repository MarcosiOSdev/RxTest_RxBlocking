/*
 * Copyright (c) 2014-2017 Razeware LLC
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
 */

import XCTest
import RxSwift
import RxTest
import RxBlocking
@testable import Testing

class TestingOperators : XCTestCase {
    
    var scheduler: TestScheduler!
    var subscription: Disposable!
    var disposable = DisposeBag()
    
    override func setUp() {
        super.setUp()
        scheduler = TestScheduler(initialClock: 0)
    }
    
    override func tearDown() {
        scheduler.scheduleAt(100) {
            self.subscription.dispose()
        }
        super.tearDown()
    }
    
    func testAmb() {
        let observer = scheduler.createObserver(String.self)
        
        let observableA = scheduler.createHotObservable([
            next(100, "a)"),
            next(200, "b)"),
            next(300, "c)")
            ])
        
        let observableB = scheduler.createHotObservable([
            next(90, "1)"),
            next(250, "2)"),
            next(300, "3)")
            ])
        
        let ambObservable = observableA.amb(observableB)
        scheduler.scheduleAt(0) {
            self.subscription = ambObservable.subscribe(observer)
        }
        scheduler.start()
        
        let results = observer.events.map {
            $0.value.element!
        }
        XCTAssertEqual(results, ["1)", "2)", "3)"])
        
    }
    
    func testFilter() {
        let observer = scheduler.createObserver(Int.self)
        
        let observable = scheduler.createHotObservable([
            next(100, 1),
            next(200, 2),
            next(300, 3),
            next(400, 2),
            next(500, 1),
            ])
        
        let filterObservable = observable.filter { $0 < 3 }
        
        scheduler.scheduleAt(0) {
            self.subscription = filterObservable.subscribe(observer)
        }
        scheduler.start()
        
        let results = observer.events.map { $0.value.element! }
        XCTAssertEqual(results, [1,2,2,1])
    }
    
    func testToArrayAsync() {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        let toArrayObservable = Observable.of("1)", "2)").subscribeOn(scheduler)
        
        XCTAssertEqual(try! toArrayObservable.toBlocking().toArray(), ["1)", "2)"])
    }
    
    func testWithViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
            // Step 2. Instantiate UIViewController with Storyboard ID
        let sut = storyboard.instantiateViewController(withIdentifier: "ViewController") as! ViewController
            
        // Step 3. Make the viewDidLoad() execute.
        _ = sut.view
        
        let observable = sut.hexTextField.rx.text.orEmpty.share()
        
        observable
            .subscribe({ event in
            print(event.element)
            
        }).disposed(by: disposable)
        
        
        sut.hexTextField.text = "Test"
        sut.hexTextField.sendActions(for: .valueChanged)
        
        
        
    }
    
    func testTextView() {
        let textView = UITextView()
        let observable = textView.rx.text.orEmpty.share()
        let expec = expectation(description: "Hello Expec")
        var resultOnAsync = ""
        observable
            .asObservable()
            .filter{ $0 != nil } //primeiro vem nil
            .skip(1) //logo apos vem um com vazio
            .subscribe(onNext: { event in
                print("OBS2: \(event)")
                resultOnAsync = event
                expec.fulfill()
            })
            .disposed(by: self.disposable)
        
        textView.text = "Hello World"
        wait(for: [expec], timeout: 3)
        XCTAssertEqual(resultOnAsync, "Hello World")
    }
    
    func testTextViewWithSchedule() {
        let textView = UITextView()
        let observable = textView.rx.text.orEmpty.share()
        let observer = scheduler.createObserver(String.self)
        scheduler.scheduleAt(0) {
            self.subscription = observable.subscribe(observer)
        }
        
        textView.text = "Hello World"
        scheduler.start()
        let results = observer.events.map {
            $0.value.element!
        }
        XCTAssertEqual(results, ["Hello World"])
    }
}
