import 'dart:async';

import 'package:test/test.dart';

import 'package:phoenix_wings/phoenix_timer.dart';

void main() {
  test("Can schedule a timer", () async {
    var called = false;
    var callback = () => called = true;
    final timer = new PhoenixTimer(callback);
    timer.reconnectAfterMs = [1];
    expect(timer.timer, null);
    expect(timer.tries, 0);
    timer.scheduleTimeout();

    await new Future<Null>.delayed(new Duration(milliseconds: 2));

    expect(called, true);
  });

  test("Can clear a timer", () async {
    var called = false;
    var callback = () => called = true;
    final timer = new PhoenixTimer(callback);
    timer.reconnectAfterMs = [10];
    timer.scheduleTimeout();

    timer.clearTimeout();
    await new Future<Null>.delayed(new Duration(milliseconds: 15));
    expect(called, false);
  });

  test("Can reset a timer", () async {
    var callback = () {};
    final timer = new PhoenixTimer(callback);
    timer.reconnectAfterMs = [1];
    timer.scheduleTimeout();
    await new Future<Null>.delayed(new Duration(milliseconds: 5));
    expect(timer.tries > 2, true);
    timer.reset();
    expect(timer.tries, 0);
  });

  test("Incrementally backsoff", () async {
    var callback = () {};
    final timer = new PhoenixTimer(callback);
    timer.reconnectAfterMs = [1, 50, 2000];
    timer.scheduleTimeout();
    await new Future<Null>.delayed(new Duration(milliseconds: 60));
    expect(timer.tries, 2);
  });
}
