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
import "./note.dart";
import "./status.dart";

import "dart:html";

const Map<Status, String> statusToClass = {
  Status.ToDo: "todo",
  Status.Doing: "doing",
  Status.Done: "done",
};

final Map<String, Status> classToStatus = {
  for (final e in statusToClass.entries) e.value: e.key
};

class ColumnModel extends EventEmitter {
  final Status _status;
  List<NoteModel> _notes = [];

  ColumnModel(this._status);

  Status get status => _status;

  void forEachNote(Function f) {
    _notes.forEach(f);
  }

  void insertNote(int index, NoteModel n) {
    _notes.insert(index, n);
    emit("insertNote", [
      index,
      n,
    ]);
  }

  void addNote(NoteModel n) {
    _notes.add(n);
    emit("addNote", [
      n,
    ]);
  }

  NoteModel getNoteById(int id) {
    return _notes.firstWhere((NoteModel n) => n.id == id);
  }

  void removeNoteById(int id) {
    NoteModel note = getNoteById(id);
    _notes.removeWhere((NoteModel n) => n.id == id);
    emit("removeNoteById", [note]);
  }
}

class ColumnView {
  ColumnModel _column;
  String _parentSelector;

  ColumnView(this._column, this._parentSelector);

  String html() {
    return """
    <div id="${statusToClass[_column.status]}" class="column">
      <div class="column__name">${_column.status.toString().split(".").last}</div>
      <div class="column__notes"></div>
    </div>""";
  }

  void update() {
    DivElement column = querySelector(_parentSelector);
    column.setInnerHtml(html());
  }

  void select() {
    DivElement column = querySelector("#${statusToClass[_column.status]}");
    column.classes.add("column-select");
  }

  void deselect() {
    DivElement column = querySelector("#${statusToClass[_column.status]}");
    column.classes.remove("column-select");
  }
}

class ColumnController extends EventEmitter {
  ColumnModel _model;
  ColumnView _view;
  List<NoteController> _notesControllers = [];

  ColumnController(this._model, String parentSelector)
      : _view = ColumnView(_model, parentSelector) {
    _model.on("addNote", (List<dynamic> args) {
      NoteModel note = args[0] as NoteModel;
      NoteController noteController = NoteController(
          note, "#${statusToClass[_model.status]} .column__notes");
      noteController.on(
          "pressDeleteControl",
          (List<dynamic> args) =>
              _model.removeNoteById((args[0] as NoteModel).id));

      _notesControllers.add(noteController);
    });

    _model.on("removeNoteById", (List<dynamic> args) {
      NoteModel note = args[0] as NoteModel;
      _notesControllers
          .removeWhere((NoteController ctrl) => ctrl.id == note.id);
      updateView();
    });
  }

  void updateView() {
    _view.update();
    _notesControllers.forEach((NoteController ctrl) => ctrl.updateView());
    initColumns();
  }

  void select() {
    _view.select();
  }

  void deselect() {
    _view.deselect();
  }

  void initColumns() {
    DivElement statDiv = querySelector("#${statusToClass[_model.status]}");
    statDiv.onDragStart.listen((MouseEvent e) {
      final DivElement note = e.target;
      final int id = int.parse(note.getAttribute("id").split("-").last);

      final DivElement column = e.currentTarget;
      final String columnId = column.getAttribute("id");
      final Status from = classToStatus[columnId];

      emit("dragStart", [id, from]);
    });

    statDiv.onDragEnd.listen((MouseEvent e) {
      emit("dragEnd", []);
    });

    statDiv.onDragOver.listen((MouseEvent e) {
      e.preventDefault();
    });

    statDiv.onDrop.listen((MouseEvent e) {
      final DivElement column = e.currentTarget;
      final String columnId = column.getAttribute("id");
      final Status to = classToStatus[columnId];
      emit("dragStop", [
        to,
      ]);
    });
  }
}