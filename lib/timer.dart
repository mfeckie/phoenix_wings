import 'dart:async';

class PhoenixTimer {
  final Function _callback;
  Timer timer;
  List<int> reconnectAfterMs;
  var tries = 0;

  PhoenixTimer(this._callback, [this.reconnectAfterMs = const [1000, 2000, 5000, 10000]]);


  void scheduleTimeout() {
     clearTimeout();
     this.timer = new Timer(timeoutDuration(), this._performTask);
  }

  void _performTask() {
    this._callback();
    this.scheduleTimeout();
  }

  Duration timeoutDuration() {
    final reconnectLength = this.reconnectAfterMs.length - 1;
    this.tries++;
    final index = this.tries > reconnectLength ? reconnectLength : this.tries;
    return new Duration(milliseconds: reconnectAfterMs[index]);
  }

  void clearTimeout() {
    timer?.cancel();
  }

  void reset() {
    this.tries = 0;
  }

}