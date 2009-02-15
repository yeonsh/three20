#import "Three20/T3MenuTextField.h"
#import "T3MenuViewCell.h"

///////////////////////////////////////////////////////////////////////////////////////////////////

static NSString* kEmpty = @" ";
static NSString* kSelected = @"`";

static CGFloat kCellPaddingY = 3;
static CGFloat kPaddingX = 8;
static CGFloat kSpacingY = 6;
static CGFloat kPaddingRatio = 1.75;
static CGFloat kClearButtonSize = 38;
static CGFloat kMinCursorWidth = 50;

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation T3MenuTextField

@synthesize cellViews = _cellViews, selectedCell = _selectedCell, lineCount = _lineCount,
  visibleLineCount = _visibleLineCount;

- (id)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _cellViews = [[NSMutableArray alloc] init];
    _selectedCell = nil;
    _lineCount = 1;
    _visibleLineCount = NSUIntegerMax;
    _cursorOrigin = CGPointZero;
    
    self.text = kEmpty;
  }
  return self;
}

- (void)dealloc {
  [_cellViews release];
  [super dealloc];
}

//////////////////////////////////////////////////////////////////////////////////////////////////

- (CGFloat)layoutCells {
  CGSize fontSize = [@"M" sizeWithFont:self.font];
  CGFloat lineIncrement = fontSize.height + kCellPaddingY*2 + kSpacingY;
  CGFloat marginY = (int)(fontSize.height/kPaddingRatio);
  CGFloat marginLeft = self.leftView
    ? kPaddingX + self.leftView.width + kPaddingX/2
    : kPaddingX;
  CGFloat marginRight = kPaddingX + (self.rightView ? kClearButtonSize : 0);

  _cursorOrigin.x = marginLeft;
  _cursorOrigin.y = marginY;
  _lineCount = 1;
  
  for (T3MenuViewCell* cell in _cellViews) {
    [cell sizeToFit];

    CGFloat lineWidth = _cursorOrigin.x + cell.frame.size.width + marginRight;
    if (lineWidth >= self.width) {
      _cursorOrigin.x = marginLeft;
      _cursorOrigin.y += lineIncrement;
      ++_lineCount;
    }

    cell.frame = CGRectMake(_cursorOrigin.x, _cursorOrigin.y-kCellPaddingY, cell.width, cell.height);
    _cursorOrigin.x += cell.frame.size.width + kPaddingX;
  }

  CGFloat remainingWidth = self.width - (_cursorOrigin.x + marginRight);
  if (remainingWidth < kMinCursorWidth) {
    _cursorOrigin.x = marginLeft;
    _cursorOrigin.y += lineIncrement;
      ++_lineCount;
  }

  return _cursorOrigin.y + fontSize.height + marginY;
}

- (void)updateHeight {
  CGFloat previousHeight = self.height;
  CGFloat newHeight = [self layoutCells];
  if (previousHeight && newHeight != previousHeight) {
    self.height = newHeight;
    [self setNeedsDisplay];
    
    SEL sel = @selector(textFieldDidResize:);
    if ([self.delegate respondsToSelector:sel]) {
      [self.delegate performSelector:sel withObject:self];
    }

    [self scrollToVisibleLine:YES];
  }
}

- (CGFloat)marginY {
  CGSize fontSize = [@"M" sizeWithFont:self.font];
  return (int)(fontSize.height/kPaddingRatio);
}

- (void)selectLastCell {
  self.selectedCell = [_cellViews objectAtIndex:_cellViews.count-1];
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// UIView

- (void)layoutSubviews {
  if (_searchSource) {
    [self layoutCells];
  } else {
    _cursorOrigin.x = kPaddingX;
    _cursorOrigin.y = [self marginY];
    if (self.leftView) {
      _cursorOrigin.x += self.leftView.width + kPaddingX/2;
    }
  }

  [super layoutSubviews];
}

- (CGSize)sizeThatFits:(CGSize)size {
  if (_visibleLineCount == NSUIntegerMax) {
    return size;
  } else {
    [self layoutIfNeeded];
    CGFloat height = [self heightWithLines:_lineCount];
    return CGSizeMake(size.width, height);
  }
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
  if (_searchSource) {
    UITouch* touch = [touches anyObject];
    if (touch.view == self) {
      self.selectedCell = nil;
    } else {
      if ([touch.view isKindOfClass:[T3MenuViewCell class]]) {
        self.selectedCell = (T3MenuViewCell*)touch.view;
      }
    }
  }
  [super touchesEnded:touches withEvent:event];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITextField

- (void)setText:(NSString*)text {
  if (_searchSource) {
    [self updateHeight];
  }
  [super setText:text];
}

- (CGRect)textRectForBounds:(CGRect)bounds {
  if (_searchSource && [self.text isEqualToString:kSelected]) {
    return CGRectMake(0, 0, 0, 0);
  } else if (_visibleLineCount == NSUIntegerMax) {
    CGFloat lineHeight = [@"M" sizeWithFont:self.font].height;
    return CGRectOffset(bounds, _cursorOrigin.x, floor(bounds.size.height/2 - lineHeight/2));
  } else {
    CGRect frame = CGRectOffset(bounds, _cursorOrigin.x, _cursorOrigin.y);
    frame.size.width -= (_cursorOrigin.x + kPaddingX + (self.rightView ? kClearButtonSize : 0));
    return frame;
  }
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
  return [self textRectForBounds:bounds];
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
  return [self textRectForBounds:bounds];
}

- (CGRect)leftViewRectForBounds:(CGRect)bounds {
  if (self.leftView) {
    return CGRectMake(
      bounds.origin.x+kPaddingX, self.marginY,
      self.leftView.frame.size.width, self.leftView.frame.size.height);
  } else {
    return bounds;
  }
}

- (CGRect)rightViewRectForBounds:(CGRect)bounds {
  if (self.rightView) {
    return CGRectMake(bounds.size.width - kClearButtonSize, bounds.size.height - kClearButtonSize,
      kClearButtonSize, kClearButtonSize);
  } else {
    return bounds;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// T3SearchTextField

- (BOOL)empty {
  return !self.text.length || [self.text isEqualToString:kEmpty]
    || [self.text isEqualToString:kSelected];
}

- (BOOL)shouldUpdate:(BOOL)emptyText {
  if (emptyText && self.empty && !self.selectedCell && self.cells.count) {
    [self selectLastCell];
    return NO;
  } else if (emptyText && self.selectedCell) {
    [self removeSelectedCell];
    [super shouldUpdate:emptyText];
    return NO;
  } else {
    return [super shouldUpdate:emptyText];
  }
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// UITableViewDelegate

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  [_tableView deselectRowAtIndexPath:indexPath animated:NO];

  id object = [_searchSource objectForRowAtIndexPath:indexPath];
  NSString* label = [_searchSource textField:self labelForRowAtIndexPath:indexPath];
  if (label) {
    [self addCellWithObject:object label:label];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray*)cells {
  NSMutableArray* cells = [NSMutableArray array];
  for (T3MenuViewCell* cellView in _cellViews) {
    [cells addObject:cellView.object ? cellView.object : [NSNull null]];
  }
  return cells;
}

- (void)addCellWithObject:(id)object label:(NSString*)label {
  T3MenuViewCell* cell = [[[T3MenuViewCell alloc] initWithFrame:CGRectZero] autorelease];

  cell.object = object;
  cell.label = label;
  [_cellViews addObject:cell];
  [self addSubview:cell];  

  // Reset text so the cursor moves to be at the end of the cellViews
  self.text = kEmpty;

  SEL sel = @selector(textField:didAddCellAtIndex:);
  if ([self.delegate respondsToSelector:sel]) {
    [self.delegate performSelector:sel withObject:self withObject:(id)_cellViews.count-1];
  }
}

- (void)removeCellWithObject:(id)object {
  for (int i = 0; i < _cellViews.count; ++i) {
    T3MenuViewCell* cell = [_cellViews objectAtIndex:i];
    if (cell.object == object) {
      [_cellViews removeObjectAtIndex:i];
      [cell removeFromSuperview];

      SEL sel = @selector(textField:didRemoveCellAtIndex:);
      if ([self.delegate respondsToSelector:sel]) {
        [self.delegate performSelector:sel withObject:self withObject:(id)i];
      }
      break;
    }
  }

  // Reset text so the cursor oves to be at the end of the cellViews
  self.text = self.text;
}

- (void)removeAllCells {
  while (_cellViews.count) {
    T3MenuViewCell* cell = [_cellViews objectAtIndex:0];
    [cell removeFromSuperview];
    [_cellViews removeObjectAtIndex:0];
  }
  
  _selectedCell = nil;
}

- (void)setSelectedCell:(T3MenuViewCell*)cell {
  if (_selectedCell) {
    _selectedCell.selected = NO;
  }
  
  _selectedCell = cell;

  if (_selectedCell) {
    _selectedCell.selected = YES;
    self.text = kSelected;
  } else if (self.cells.count) {
    self.text = kEmpty;
  }
}

- (void)removeSelectedCell {
  if (_selectedCell) {
    [self removeCellWithObject:_selectedCell.object];
    _selectedCell = nil;

    if (_cellViews.count) {
      self.text = kEmpty;
    } else {
      self.text = @"";
    }
  }
}

- (CGFloat)lineTop:(int)lineNumber {
  if (lineNumber == 0) {
    return 0;
  } else {
    CGFloat lineHeight = [@"M" sizeWithFont:self.font].height;
    CGFloat lineSpacing = kCellPaddingY*2 + kSpacingY;
    CGFloat marginY = (int)(lineHeight/kPaddingRatio);
    CGFloat lineTop = marginY + lineHeight*lineNumber + lineSpacing*lineNumber;
    return lineTop - (kCellPaddingY+kSpacingY);
  }
}

- (CGFloat)lineCenter:(int)lineNumber {
  CGFloat lineTop = [self lineTop:lineNumber];
  CGFloat lineHeight = [@"M" sizeWithFont:self.font].height + kCellPaddingY*2 + kSpacingY;
  return lineTop + floor(lineHeight/2);
}

- (CGFloat)heightWithLines:(int)lines {
  CGFloat lineHeight = [@"M" sizeWithFont:self.font].height;
  CGFloat lineSpacing = kCellPaddingY*2 + kSpacingY;
  CGFloat marginY = (int)(lineHeight/kPaddingRatio);
  return marginY + lineHeight*lines + lineSpacing*(lines ? lines-1 : 0) + marginY;
}

- (void)scrollToVisibleLine:(BOOL)animated {
  if (_visibleLineCount != NSUIntegerMax && self.editing) {
    UIScrollView* scrollView = (UIScrollView*)[self firstParentOfClass:[UIScrollView class]];
    if (scrollView) {
      if (_lineCount > _visibleLineCount) {
        int topLine = _lineCount - _visibleLineCount;
        CGFloat offset = [self lineCenter:topLine-1];
        [scrollView setContentOffset:CGPointMake(0, self.y+offset) animated:animated];
      } else {
        [scrollView setContentOffset:CGPointMake(0, self.y) animated:animated];
      }
    }
  }
}

- (void)scrollToEditingLine:(BOOL)animated {
  UIScrollView* scrollView = (UIScrollView*)[self firstParentOfClass:[UIScrollView class]];
  if (scrollView) {
    CGFloat offset = _lineCount == 1 ? 0 : [self lineTop:_lineCount-1];
    [scrollView setContentOffset:CGPointMake(0, self.y+offset) animated:animated];
  }
}

@end
