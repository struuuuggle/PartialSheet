//
//  PartialSheetViewModifier.swift
//  PartialModal
//
//  Created by Miotto Andrea on 09/11/2019.
//  Copyright © 2019 Miotto Andrea. All rights reserved.
//

import SwiftUI

/// This is the modifier for the Partial Sheet
struct PartialSheet<SheetContent>: ViewModifier where SheetContent: View {
    
    // MARK: - Public Properties
    
    /// Tells if the sheet should be presented or not
    @Binding var presented: Bool
    
    /// The color of the background
    var backgroundColor: Color
    
    /// The color of the Handlander Bar
    var handlerBarColor: Color
    
    /// Tells if should be there a cover between the Partial Sheet and the Content
    var enableCover: Bool
    
    /// The color of the cover
    var coverColor: Color
    
    /// The action called when the Partial Sheet will disappear
    var onDismiss: (() -> Void)?

    var view: () -> SheetContent
    
    // MARK: - Private Properties
    
    /// The rect containing the content
    @State private var presenterContentRect: CGRect = .zero
    
    /// The rect containing the content
    @State private var sheetContentRect: CGRect = .zero
    
    /// The point for the top anchor
    private var topAnchor: CGFloat {
        return max(presenterContentRect.height - sheetContentRect.height - handlerSectionHeight, 110)
    }
    
    /// The he point for the bottom anchor
    private var bottomAnchor: CGFloat {
        return UIScreen.main.bounds.height + 5
    }
    
    /// The current anchor point, based if the **presented** property is true or false
    private var currentAnchorPoint: CGFloat {
        return presented ?
            topAnchor :
        bottomAnchor
    }
    
    /// The height of the handler bar section
    private var handlerSectionHeight: CGFloat {
        return 30
    }
    
    /// The Gesture State for the drag gesture
    @GestureState private var dragState = DragState.inactive
    
    // MARK: - Content Builders
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .background(
                    GeometryReader { proxy -> AnyView in
                        let rect = proxy.frame(in: .global)
                        // This avoids an infinite layout loop
                        if rect.integral != self.presenterContentRect.integral {
                            DispatchQueue.main.async {
                                self.presenterContentRect = rect
                            }
                        }
                        return AnyView(EmptyView())
                    }
            )
            sheet()
                .edgesIgnoringSafeArea(.vertical)
        }
    }
    
    /// This is the builder for the sheet content
    func sheet()-> some View {
        // Build the drag gesture
        let drag = DragGesture()
            .updating($dragState) { drag, state, _ in
                let yOffset = drag.translation.height
                let threshold = CGFloat(-50)
                let stiffness = CGFloat(0.3)
                if yOffset > threshold {
                    state = .dragging(translation: drag.translation)
                } else if
                    // if above threshold and belove ScreenHeight make it elastic
                    -yOffset + self.sheetContentRect.height <
                        UIScreen.main.bounds.height + self.handlerSectionHeight
                {
                    let distance = yOffset - threshold
                    let translationHeight = threshold + (distance * stiffness)
                    state = .dragging(translation: CGSize(width: drag.translation.width, height: translationHeight))
                }
        }
        .onEnded(onDragEnded)
        
        return ZStack {
            // Attach the cover view
            if presented && enableCover {
                Rectangle()
                    .foregroundColor(coverColor)
                    .edgesIgnoringSafeArea(.vertical)
                    .onTapGesture {
                        withAnimation {
                            self.presented = false
                        }
                }
            }
            // The Sheet View
            Group {
                VStack(spacing: 0) {
                    // This is the little rounded bar (handler) on top of the sheet
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: CGFloat(5.0) / 2.0)
                            .frame(width: 40, height: 5)
                            .foregroundColor(self.handlerBarColor)
                        Spacer()
                    }
                    .frame(height: handlerSectionHeight)
                    VStack {
                        // Attach the content of the sheet
                        self.view()
                            .background(
                                GeometryReader { proxy -> AnyView in
                                    let rect = proxy.frame(in: .global)
                                    // This avoids an infinite layout loop
                                    if rect.integral != self.sheetContentRect.integral {
                                        DispatchQueue.main.async {
                                            self.sheetContentRect = rect
                                        }
                                    }
                                    return AnyView(EmptyView())
                                }
                        )
                    }
                    Spacer()
                }
                .frame(width: UIScreen.main.bounds.width)
                .background(backgroundColor)
                .cornerRadius(10.0)
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.13), radius: 10.0)
                .offset(y: self.presented ?
                    self.topAnchor + self.dragState.translation.height : self.bottomAnchor - self.dragState.translation.height
                )
                    .animation(self.dragState.isDragging ?
                        nil : .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0))
                    .gesture(drag)
            }
        }
        .onDisappear {
            self.onDismiss?()
        }
    }
    
    // MARK: - Private Methods
    
    /// The method called when the drag ends. It moves the sheet in the correct position based on the last drag gesture
    private func onDragEnded(drag: DragGesture.Value) {
        /// The drag direction
        let verticalDirection = drag.predictedEndLocation.y - drag.location.y
        /// The current sheet position
        let cardTopEdgeLocation = topAnchor + drag.translation.height
        
        // Get the closest anchor point based on the current position of the sheet
        let closestPosition: CGFloat
        
        if (cardTopEdgeLocation - topAnchor) < (bottomAnchor - cardTopEdgeLocation) {
            closestPosition = topAnchor
        } else {
            closestPosition = bottomAnchor
        }
        
        // Set the correct anchor point based on the vertical direction of the drag
        if verticalDirection > 1 {
            DispatchQueue.main.async {
                self.presented = false
            }
        } else if verticalDirection < 0 {
            self.presented = true
        } else {
            self.presented = (closestPosition == topAnchor)
        }
    }
}
