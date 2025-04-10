import 'package:anistar_tv/app/app_routes.dart'; // Use package import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart'; // Import go_router

import '../../domain/models/series_model.dart'; // Corrected relative path
import '../../domain/usecases/get_series_list_usecase.dart'; // Corrected relative path
import '../bloc/series_list_bloc.dart';
import '../widgets/series_card.dart';

// Removed incorrect service_locator import
class SeriesListScreen extends StatefulWidget {
  final String url; // URL passed from the previous screen (e.g., Home Screen)

  const SeriesListScreen({super.key, required this.url});

  @override
  State<SeriesListScreen> createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  final FocusNode _gridFocusNode = FocusNode(); // Focus node for the GridView itself
  List<FocusNode> _itemFocusNodes = []; // Focus nodes for individual items
  int _focusedIndex = 0; // Track the index of the currently focused item
  final int _crossAxisCount = 3; // Number of columns

  @override
  void initState() {
    super.initState();
    // Request focus for the grid after the first frame to allow focus traversal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initial data fetch is handled by BlocProvider create below
      // Ensure the grid itself can receive key events initially
      if (mounted) {
        FocusScope.of(context).requestFocus(_gridFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _gridFocusNode.dispose();
    // Dispose item focus nodes to prevent memory leaks
    for (var node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Handles key events for navigating the grid
  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event, List<Series> series) {
    if (event is! RawKeyDownEvent) {
      return KeyEventResult.ignored; // Ignore key up events
    }

    // Find the currently focused item index, default to _focusedIndex if none has focus
    int currentFocusedIndex = _itemFocusNodes.indexWhere((node) => node.hasFocus);
    if (currentFocusedIndex == -1) {
      currentFocusedIndex = _focusedIndex; // Use the tracked index if no node reports focus
    }

    int newFocusedIndex = currentFocusedIndex;
    bool moved = false;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // Move right: Check if not in the last column and not the last item
      if ((currentFocusedIndex + 1) % _crossAxisCount != 0 && currentFocusedIndex < series.length - 1) {
        newFocusedIndex = currentFocusedIndex + 1;
        moved = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // Move left: Check if not in the first column
      if (currentFocusedIndex % _crossAxisCount != 0) {
        newFocusedIndex = currentFocusedIndex - 1;
        moved = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      // Move up: Check if not in the first row
      if (currentFocusedIndex >= _crossAxisCount) {
        newFocusedIndex = currentFocusedIndex - _crossAxisCount;
        moved = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      // Move down: Check if a corresponding item exists in the next row
      if (currentFocusedIndex + _crossAxisCount < series.length) {
        newFocusedIndex = currentFocusedIndex + _crossAxisCount;
        moved = true;
      } else if (currentFocusedIndex < series.length - 1 &&
          (currentFocusedIndex ~/ _crossAxisCount) < ((series.length - 1) ~/ _crossAxisCount)) {
        // If in the second to last row and the last row is shorter, move to the last item
        newFocusedIndex = series.length - 1;
        moved = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
      // Handle selection: Trigger onTap for the focused item
      if (currentFocusedIndex >= 0 && currentFocusedIndex < series.length) {
        _itemFocusNodes[currentFocusedIndex].requestFocus(); // Ensure focus
        print(
          "Selected series: ${series[currentFocusedIndex].title} - URL: ${series[currentFocusedIndex].dataUrl}",
        ); // Corrected field name
        // Navigate using go_router's push method with the path and extra
        context.push(
          AppRoutes.videoList, // Use the path string defined in AppRoutes
          extra: series[currentFocusedIndex].dataUrl, // Pass dataUrl via 'extra'
        );
      }
      return KeyEventResult.handled; // Mark event as handled
    }

    if (moved && newFocusedIndex != currentFocusedIndex) {
      setState(() {
        FocusScope.of(context).requestFocus(_itemFocusNodes[newFocusedIndex]);
        _focusedIndex = newFocusedIndex; // Update the tracked focused index
        _ensureVisible(newFocusedIndex); // Ensure the new item is visible
      });
      return KeyEventResult.handled; // Mark event as handled
    }

    return KeyEventResult.ignored; // Event not handled, propagate
  }

  // Scrolls the list to ensure the item at the given index is visible
  void _ensureVisible(int index) {
    if (index < 0 ||
        index >= _itemFocusNodes.length ||
        !_itemFocusNodes[index].hasListeners ||
        _itemFocusNodes[index].context == null) {
      // Index out of bounds or node not attached to the tree
      return;
    }
    Scrollable.ensureVisible(
      _itemFocusNodes[index].context!,
      duration: const Duration(milliseconds: 200), // Faster scroll animation
      curve: Curves.easeInOut, // Animation curve
      alignment: 0.5, // Center the item vertically in the viewport
      alignmentPolicy:
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd, // Keep item visible at the bottom edge if scrolling down
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Create the BLoC instance. It will be automatically disposed by BlocProvider.
      create:
          (context) => SeriesListBloc(
            getSeriesListUseCase: context.read<GetSeriesListUseCase>(), // Use context.read
          )..add(LoadSeriesList(url: widget.url)), // Initial data fetch trigger
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Series'), // Or use widget.url or dynamic title
        ),
        body: BlocConsumer<SeriesListBloc, SeriesListState>(
          listener: (context, state) {
            // Optional: Show messages or handle errors based on state changes
            switch (state) {
              case SeriesListError(message: final message):
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading series: $message')));
              case SeriesListInitial():
              case SeriesListLoading():
              case SeriesListLoaded():
                // Do nothing for other states
                break;
            }
          },
          builder: (context, state) {
            switch (state) {
              case SeriesListInitial():
                return const Center(child: CircularProgressIndicator());
              case SeriesListLoading():
                return const Center(child: CircularProgressIndicator());
              case SeriesListError(message: final message):
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $message'),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => context.read<SeriesListBloc>().add(LoadSeriesList(url: widget.url)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              case SeriesListLoaded(series: final seriesList):
                if (seriesList.isEmpty) {
                  return const Center(child: Text('No series found.'));
                }

                // Initialize or update focus nodes if the list size changes
                if (_itemFocusNodes.length != seriesList.length) {
                  for (var node in _itemFocusNodes) {
                    node.dispose();
                  } // Dispose old nodes
                  _itemFocusNodes = List.generate(seriesList.length, (index) => FocusNode());
                  // Request focus for the first item after the build cycle
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _itemFocusNodes.isNotEmpty) {
                      FocusScope.of(context).requestFocus(_itemFocusNodes[0]);
                      setState(() {
                        _focusedIndex = 0;
                      });
                      _ensureVisible(0);
                    }
                  });
                }

                return Focus(
                  focusNode: _gridFocusNode, // Assign the grid's focus node
                  onKey: (node, event) => _handleKeyEvent(node, event, seriesList),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _crossAxisCount, // Use the defined column count
                      childAspectRatio: 1.8, // Adjust aspect ratio for item size (taller)
                      crossAxisSpacing: 15, // Horizontal spacing
                      mainAxisSpacing: 15, // Vertical spacing
                    ),
                    itemCount: seriesList.length,
                    itemBuilder: (context, index) {
                      final series = seriesList[index];
                      final focusNode = _itemFocusNodes[index];

                      return Focus(
                        focusNode: focusNode,
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            setState(() {
                              _focusedIndex = index; // Update tracked index on focus change
                              _ensureVisible(index);
                            });
                          }
                        },
                        child: SeriesCard(
                          series: series,
                          isFocused: focusNode.hasFocus,
                          onTap: () {
                            // Handle tap event, e.g., navigate or select
                            print("Tapped series: ${series.title} - URL: ${series.dataUrl}");
                            // Ensure the tapped item receives focus
                            FocusScope.of(context).requestFocus(focusNode);
                            setState(() {
                              _focusedIndex = index;
                            });
                            // Navigate using go_router's push method on tap
                            context.push(
                              AppRoutes.videoList, // Use the path string
                              extra: series.dataUrl, // Pass dataUrl via 'extra'
                            );
                          },
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(20), // Padding around the grid
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
