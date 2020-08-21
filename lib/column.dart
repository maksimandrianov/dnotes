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

import "dart:html";

import 'package:json_annotation/json_annotation.dart';

import "event_emitter.dart";
import "note.dart";
import "status.dart";

part "column.g.dart";

const Map<Status, String> statusToClass = {
  Status.ToDo: "todo",
  Status.Doing: "doing",
  Status.Done: "done",
};

final Map<String, Status> classToStatus = {
  for (final e in statusToClass.entries) e.value: e.key
};

@JsonSerializable()
class ColumnModel with EventEmitter {
  final Status _status;
  List<NoteModel> _notes;

  ColumnModel(Status status, List<NoteModel> notes)
      : _status = status,
        _notes = notes;

  factory ColumnModel.Empty(Status status) => ColumnModel(status, []);

  factory ColumnModel.fromJson(Map<String, dynamic> json) =>
      _$ColumnModelFromJson(json);

  Map<String, dynamic> toJson() => _$ColumnModelToJson(this);

  Status get status => _status;

  List<NoteModel> get notes => _notes;

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

  static const Map<Status, String> statusToSelectClass = const <Status, String>{
    Status.ToDo: "column-select-lightpink",
    Status.Doing: "column-select-lightblue",
    Status.Done: "column-select-lightgreen",
  };

  ColumnView(this._column, this._parentSelector);

  String html() => """
    <div id="${statusToClass[_column.status]}" class="column">
      <div class="column__name">${_column.status.toString().split(".").last}</div>
      <div class="column__notes"></div>
    </div>""";

  void update() {
    DivElement column = querySelector(_parentSelector);
    column.setInnerHtml(html());
  }

  void select({Status status = null}) {
    deselectAll();
    DivElement column = querySelector("#${statusToClass[_column.status]}");
    if (status == null) {
      column.classes.add("column-select-yellow");
      return;
    }

    column.classes.add(statusToSelectClass[status]);
  }

  void deselectAll() {
    DivElement column = querySelector("#${statusToClass[_column.status]}");
    column.classes.removeWhere((String cls) => cls.startsWith("column-select"));
  }
}

class ColumnController with EventEmitter {
  ColumnModel _model;
  ColumnView _view;
  List<NoteController> _notesControllers;

  ColumnController(this._model, String parentSelector)
      : _view = ColumnView(_model, parentSelector) {
    _notesControllers = List<NoteController>.from(
        _model.notes.map(createAndInitNoteController));

    _model.on("addNote", (List<dynamic> args) {
      NoteModel note = args[0] as NoteModel;
      _notesControllers.add(createAndInitNoteController(note));
    });

    _model.on("removeNoteById", (List<dynamic> args) {
      NoteModel note = args[0] as NoteModel;
      _notesControllers
          .removeWhere((NoteController ctrl) => ctrl.id == note.id);
      updateView();
    });
  }

  NoteController createAndInitNoteController(NoteModel note) {
    NoteController noteController =
        NoteController(note, "#${statusToClass[_model.status]} .column__notes");
    noteController.on("pressDeleteControl",
        (List<dynamic> args) => _model.removeNoteById(note.id));
    return noteController;
  }

  void updateView() {
    _view.update();
    _notesControllers.forEach((NoteController ctrl) => ctrl.updateView());
    initColumns();
  }

  void select({Status status = null}) {
    _view.select(status: status);
  }

  void deselect() {
    _view.deselectAll();
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

    int dragEnterLeaveCounter = 0;
    statDiv.onDragEnter.listen((MouseEvent e) {
      ++dragEnterLeaveCounter;
      emit("dragEnter", [
        _model.status,
      ]);
    });

    statDiv.onDragLeave.listen((MouseEvent e) {
      --dragEnterLeaveCounter;
      if (dragEnterLeaveCounter == 0) {
        emit("dragLeave", [
          _model.status,
        ]);
      }
    });

    statDiv.onDragOver.listen((MouseEvent e) {
      e.preventDefault();
    });

    statDiv.onDrop.listen((MouseEvent e) {
      dragEnterLeaveCounter = 0;
      final DivElement column = e.currentTarget;
      final String columnId = column.getAttribute("id");
      final Status to = classToStatus[columnId];
      emit("dragStop", [
        to,
      ]);
    });
  }
}
