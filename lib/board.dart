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
import "./column.dart";
import "./note.dart";
import "./status.dart";

import "dart:html";

class BoardModel extends EventEmitter {
  Map<Status, ColumnModel> board = {};
  int dragNoteId;
  Status dragNoteFrom;
  Status dragNoteTo;

  BoardModel() {
    Status.values.forEach((Status s) {
      board[s] = ColumnModel(s);
    });
  }

  void addToDoNote(NoteModel note) {
    board[Status.ToDo].addNote(note);
    emit("addToDoNote", [
      note,
    ]);
  }

  void updateNoteStatus(int noteId, Status oldStatus, Status newStatus) {
    if (oldStatus != newStatus) {
      ColumnModel oldColumnModel = board[oldStatus];
      NoteModel note = oldColumnModel.getNoteById(noteId);
      oldColumnModel.removeNoteById(noteId);
      note.status = newStatus;
      board[newStatus].addNote(note);
      emit("updateNoteStatus", [
        oldStatus,
        newStatus,
        note,
      ]);
    }
  }
}

class BoardView {
  BoardModel _board;
  String _parentSelector;

  BoardView(this._board, this._parentSelector);

  String html() {
    String innerHtml = "";
    _board.board.keys.forEach((Status s) {
      String optionalHtml = "";
      if (s == Status.ToDo) {
        optionalHtml += """
        <div class="form-new-note">
          <input type="text" class="form-new-note__header" placeholder="Header">
          <input type="text" class="form-new-note__text" placeholder="Text">
          <button class="form-new-note__btn">Create</button>
          <div class="form-new-note__errors"></div>
        </div>""";
      }
      innerHtml += """
      <div class="column-wrapper">
        <div class="${statusToClass[s]}-box"></div>
        ${optionalHtml}
      </div>""";
    });
    return '<div class="board">${innerHtml}</div>';
  }

  void update() {
    DivElement dnotes = querySelector(_parentSelector);
    dnotes.setInnerHtml(html());
  }
}

class BoardController extends EventEmitter {
  BoardModel _model;
  BoardView _view;
  Map<Status, ColumnController> _columnControllers = {};

  BoardController(this._model, String parentSelector)
      : _view = BoardView(_model, parentSelector) {
    Status.values.forEach((Status s) {
      if (_model.board.containsKey(s)) {
        ColumnController columnController =
            ColumnController(_model.board[s], ".${statusToClass[s]}-box");
        columnController.on("dragStart", (List<dynamic> args) {
          _model.dragNoteId = args[0] as int;
          _model.dragNoteFrom = args[1] as Status;

          _columnControllers.values
              .forEach((ColumnController ctrl) => ctrl.select());
        });

        columnController.on("dragStop", (List<dynamic> args) {
          _model.dragNoteTo = args[0] as Status;
          _model.updateNoteStatus(
              _model.dragNoteId, _model.dragNoteFrom, _model.dragNoteTo);
        });

        columnController.on("dragEnd", (List<dynamic> args) {
          _columnControllers.values
              .forEach((ColumnController ctrl) => ctrl.deselect());
        });

        columnController.on("dragEnter", (List<dynamic> args) {
          final Status s = args[0] as Status;
          _columnControllers[s].select(status: s);
        });

        columnController.on("dragLeave", (List<dynamic> args) {
          final Status s = args[0] as Status;
          _columnControllers[s].select();
        });

        _columnControllers[s] = columnController;
      }
    });

    _model.on("addToDoNote", (List<dynamic> args) {
      if (_columnControllers.containsKey(Status.ToDo)) {
        _columnControllers[Status.ToDo].updateView();
      }
    });

    _model.on("updateNoteStatus", (List<dynamic> args) {
      for (final p in args.getRange(0, 2)) {
        final Status s = p as Status;
        _columnControllers[s].updateView();
      }
    });
  }

  void updateView() {
    _view.update();
    _columnControllers.values
        .forEach((ColumnController ctrl) => ctrl.updateView());
    initButton();
  }

  void initButton() {
    InputElement headerInput = querySelector(".form-new-note__header");
    InputElement textInput = querySelector(".form-new-note__text");
    ButtonElement createBtn = querySelector(".form-new-note__btn");
    DivElement errorsDiv = querySelector(".form-new-note__errors");
    createBtn.onClick.listen((MouseEvent e) {
      errorsDiv.innerText = "";
      if (headerInput.value.isEmpty) {
        errorsDiv.innerText += "Header is empty.\n";
        return;
      }

      addToDoNote(headerInput.value, textInput.value);
      headerInput.value = "";
      textInput.value = "";
    });
  }

  void addToDoNote(String header, String text) {
    _model.addToDoNote(NoteModel(header, text, Status.ToDo));
  }
}
