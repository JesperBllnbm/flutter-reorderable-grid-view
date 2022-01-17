import 'package:flutter/cupertino.dart';
import 'package:flutter_reorderable_grid_view/new/entities/reorderable_entity.dart';
import 'package:flutter_reorderable_grid_view/new/widgets/reorderable_animated_child.dart';

typedef DraggableBuilder = Widget Function(List<Widget> draggableChildren);

class ReorderableBuilder extends StatefulWidget {
  final List<Widget> children;
  final DraggableBuilder builder;
  final ReorderCallback onReorder;

  const ReorderableBuilder({
    required this.children,
    required this.builder,
    required this.onReorder,
    Key? key,
  }) : super(key: key);

  @override
  _ReorderableBuilderState createState() => _ReorderableBuilderState();
}

class _ReorderableBuilderState extends State<ReorderableBuilder> {
  ReorderableEntity? draggedReorderableEntity;
  var childrenMap = <int, ReorderableEntity>{};

  var offsetMap = <int, Offset>{};

  @override
  void initState() {
    super.initState();

    _updateChildren();
  }

  @override
  void didUpdateWidget(covariant ReorderableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.children.length != widget.children.length) {
      _updateChildren();
    }
  }

  void _updateChildren() {
    var counter = 0;

    final checkDuplicatedKeyList = <int>[];

    for (final child in widget.children) {
      final hashKey = child.key.hashCode;

      if (!checkDuplicatedKeyList.contains(hashKey)) {
        checkDuplicatedKeyList.add(hashKey);
      } else {
        throw Exception('Duplicated key $hashKey found in children');
      }

      final reorderableEntity = childrenMap[hashKey];

      if (reorderableEntity == null) {
        childrenMap[hashKey] = ReorderableEntity(
          child: child,
          originalOrderId: counter,
          updatedOrderId: counter,
        );
      }

      counter++;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      _getDraggableChildren(),
    );
  }

  List<Widget> _getDraggableChildren() {
    final draggableChildren = <Widget>[];
    final sortedChildren = childrenMap.values.toList()
      ..sort((a, b) => a.originalOrderId.compareTo(b.originalOrderId));

    for (final reorderableEntity in sortedChildren) {
      draggableChildren.add(
        ReorderableAnimatedChild(
          draggedReorderableEntity: draggedReorderableEntity,
          reorderableEntity: reorderableEntity,
          onDragUpdate: _handleDragUpdate,
          onCreated: _handleCreated,
          onAnimationEnd: _handleChildAnimationEnd,
          onDragStarted: _handleDragStarted,
          onDragEnd: _handleDragEnd,
        ),
      );
    }

    return draggableChildren;
  }

  void _handleCreated(int hashKey, GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      assert(false, 'RenderBox of child should not be null!');
    } else {
      final reorderableEntity = childrenMap[hashKey]!;
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      childrenMap[hashKey] = reorderableEntity.copyWith(
        size: size,
        originalOffset: offset,
        updatedOffset: offset,
      );
      print('Added child $hashKey with position $offset');
      offsetMap[reorderableEntity.updatedOrderId] = offset;
    }
  }

  void _handleDragStarted(ReorderableEntity reorderableEntity) {
    setState(() {
      draggedReorderableEntity = reorderableEntity;
    });
  }

  void _handleDragUpdate(int hashKey, DragUpdateDetails details) {
    _checkForCollisions(
      details: details,
    );
  }

  void _checkForCollisions({
    required DragUpdateDetails details,
  }) {
    final draggedReorderableEntity = this.draggedReorderableEntity!;
    final draggedHashKey = draggedReorderableEntity.child.key.hashCode;

    final collisionMapEntry = _getCollisionMapEntry(
      draggedHashKey: draggedHashKey,
      details: details,
    );

    if (collisionMapEntry != null) {
      // update for collision entity
      final updatedCollisionEntity = collisionMapEntry.value.copyWith(
        updatedOffset: draggedReorderableEntity.updatedOffset,
        updatedOrderId: draggedReorderableEntity.updatedOrderId,
      );
      childrenMap[collisionMapEntry.key] = updatedCollisionEntity;

      // update for dragged entity
      final updatedDraggedEntity = draggedReorderableEntity.copyWith(
        updatedOffset: collisionMapEntry.value.updatedOffset,
        updatedOrderId: collisionMapEntry.value.updatedOrderId,
      );
      childrenMap[draggedHashKey] = updatedDraggedEntity;

      setState(() {
        this.draggedReorderableEntity = updatedDraggedEntity;
      });

      ///
      /// some prints for me
      ///

      final draggedOrderIdBefore = draggedReorderableEntity.updatedOrderId;
      final draggedOrderIdAfter = updatedDraggedEntity.updatedOrderId;

      final collisionOrderIdBefore = collisionMapEntry.value.updatedOrderId;
      final collisionOrderIdAfter = updatedCollisionEntity.updatedOrderId;

      print('');
      print('---- Dragged child at position $draggedOrderIdBefore ----');
      print(
          'Dragged child from position $draggedOrderIdBefore to $draggedOrderIdAfter');
      print(
          'Collisioned child from position $collisionOrderIdBefore to $collisionOrderIdAfter');
      print('---- END ----');
      print('');
    }
  }

  MapEntry<int, ReorderableEntity>? _getCollisionMapEntry({
    required int draggedHashKey,
    required DragUpdateDetails details,
  }) {
    for (final entry in childrenMap.entries) {
      final localPosition = entry.value.updatedOffset;
      final size = entry.value.size;

      if (entry.key == draggedHashKey) {
        continue;
      }

      // checking collision with full item size and local position
      if (details.localPosition.dx >= localPosition.dx &&
          details.localPosition.dy >= localPosition.dy &&
          details.localPosition.dx <= localPosition.dx + size.width &&
          details.localPosition.dy <= localPosition.dy + size.height) {
        return entry;
      }
    }
  }

  void _handleChildAnimationEnd(
    int hashKey,
    ReorderableEntity reorderableEntity,
  ) {}

  int getChildIndex(int hashKey) => widget.children.indexWhere(
        (element) => element.key.hashCode == hashKey,
      );

  /// Updates all children in map when dragging ends.
  ///
  /// Every updated child gets a new offset and orderId.
  void _handleDragEnd(DraggableDetails details) {
    final originalOffset = draggedReorderableEntity!.originalOffset;
    final updatedOffset = draggedReorderableEntity!.updatedOffset;

    if (originalOffset != updatedOffset) {
      int oldIndex = -1;
      int newIndex = -1;

      for (final offsetMapEntry in offsetMap.entries) {
        final offset = offsetMapEntry.value;

        if (offset == draggedReorderableEntity!.originalOffset) {
          oldIndex = offsetMapEntry.key;
        } else if (offset == draggedReorderableEntity!.updatedOffset) {
          newIndex = offsetMapEntry.key;
        }

        if (oldIndex >= 0 && newIndex >= 0) {
          break;
        }
      }
      print('Update: Old index $oldIndex and new index $newIndex');

      final updatedChildrenMap = <int, ReorderableEntity>{};

      for (final childrenMapEntry in childrenMap.entries) {
        final reorderableEntity = childrenMapEntry.value;

        final updatedEntryValue = childrenMapEntry.value.copyWith(
          originalOrderId: reorderableEntity.updatedOrderId,
          originalOffset: reorderableEntity.updatedOffset,
        );

        updatedChildrenMap[childrenMapEntry.key] = updatedEntryValue;
      }

      childrenMap = updatedChildrenMap;
    } else {
      print('No update while reordered children!');
    }

    setState(() {
      draggedReorderableEntity = null;
    });
  }
}
