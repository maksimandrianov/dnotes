// The MIT License (MIT)
// Copyright (c) 2020 Maksim Andrianov
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

import "./event_emitter.dart";
import "./status.dart";

import "dart:html";

int _id = 0;

class NoteModel extends EventEmitter {
  final int id;
  String header;
  String body;
  Status status;

  NoteModel(this.header, this.body, this.status) : id = _id++ {}
}

class NoteView {
  NoteModel _note;
  String _parentSelector;

  NoteView(this._note, this._parentSelector);

  String html() {
    return """
        <div class="note" draggable="true" id="note-${_note.id}">
            <div class="note__controls">
                <span class="note__control note__control-delete">Delete</span>
            </div>
            <div class="note__header">${_note.header}</div>
            <div class="note__body">${_note.body}</div>
        </div>""";
  }

  void update() {
    DivElement notes = querySelector(_parentSelector);
    notes.children.add(Element.html(html()));
  }
}

class NoteController extends EventEmitter {
  NoteModel _model;
  NoteView _view;

  NoteController(this._model, String parentSelector)
      : _view = NoteView(_model, parentSelector) {}

  int get id => _model.id;

  void updateView() {
    _view.update();
    initControls();
  }

  void initControls() {
    SpanElement deleteControl =
        querySelector("#note-${_model.id} .note__control-delete");

    deleteControl.onClick.listen((MouseEvent e) {
      emit("pressDeleteControl", [
        _model,
      ]);
    });
  }
}
