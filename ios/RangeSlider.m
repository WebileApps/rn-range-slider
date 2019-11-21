//
// Created by Tigran Sahakyan on 2019-01-14.
// Copyright (c) 2019 tigrans. All rights reserved.
//

#import <limits.h>
#import "RangeSlider.h"

#define TYPE_NUMBER @"number"
#define TYPE_TIME @"time"
#define NONE @"none"
#define BUBBLE @"bubble"
#define TOP @"top"
#define BOTTOM @"bottom"
#define CENTER @"center"
#define SQRT_3 (float) sqrt(3)
#define SQRT_3_2 SQRT_3 / 2
#define CLAMP(x, min, max) (x < min ? min : x > max ? max : x)

const int THUMB_LOW = 0;
const int THUMB_HIGH = 1;
const int THUMB_MIDDLE = 2;
const int THUMB_NONE = -1;

@interface RangeSlider () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIPanGestureRecognizer *pangestureRecognizer;

@end

@implementation RangeSlider

+ (UIColor *)colorWithHexString:(const NSString *)hexString {
    NSString *colorString = [[hexString stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    CGFloat alpha, red, blue, green;
    switch ([colorString length]) {
        case 3: // #RGB
            alpha = 1.0f;
            red = [self colorComponentFrom:colorString start:0 length:1];
            green = [self colorComponentFrom:colorString start:1 length:1];
            blue = [self colorComponentFrom:colorString start:2 length:1];
            break;
        case 4: // #RGBA
            red = [self colorComponentFrom:colorString start:0 length:1];
            green = [self colorComponentFrom:colorString start:1 length:1];
            blue = [self colorComponentFrom:colorString start:2 length:1];
            alpha = [self colorComponentFrom:colorString start:3 length:1];
            break;
        case 6: // #RRGGBB
            alpha = 1.0f;
            red = [self colorComponentFrom:colorString start:0 length:2];
            green = [self colorComponentFrom:colorString start:2 length:2];
            blue = [self colorComponentFrom:colorString start:4 length:2];
            break;
        case 8: // #RRGGBBAA
            red = [self colorComponentFrom:colorString start:0 length:2];
            green = [self colorComponentFrom:colorString start:2 length:2];
            blue = [self colorComponentFrom:colorString start:4 length:2];
            alpha = [self colorComponentFrom:colorString start:6 length:2];
            break;
        default:
            [NSException raise:@"Invalid color value" format:@"Color value %@ is invalid.  It should be a hex value of the form #RBG, #ARGB, #RRGGBB, or #AARRGGBB", hexString];
            break;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (CGFloat)colorComponentFrom:(const NSString *)string start:(NSUInteger)start length:(NSUInteger)length {
    NSString *substring = [string substringWithRange:NSMakeRange(start, length)];
    NSString *fullHex = length == 2 ? substring : [NSString stringWithFormat:@"%@%@", substring, substring];
    unsigned hexComponent;
    [[NSScanner scannerWithString:fullHex] scanHexInt:&hexComponent];
    return hexComponent / 255.0;
}

UIFont *labelFont;
NSDateFormatter *dateTimeFormatter;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor:[UIColor clearColor]];
        dateTimeFormatter = [[NSDateFormatter alloc] init];
        _activeThumb = THUMB_NONE;
        _min = LONG_MIN;
        _max = LONG_MAX;
        _lowValue = _min;
        _highValue = _max;
        _initialLowValueSet = false;
        _initialHighValueSet = false;
        labelFont = [UIFont systemFontOfSize:14];
        _step = 1;
        [self _initiazeGestureRecognizer];
    }
    return self;
}

- (void)setLineWidth:(float)lineWidth {
    _lineWidth = lineWidth;
    [self setNeedsDisplay];
}

- (void)setThumbRadius:(float)thumbRadius {
    _thumbRadius = thumbRadius;
    [self setNeedsDisplay];
}

- (void)setThumbBorderWidth:(float)thumbBorderWidth {
    _thumbBorderWidth = thumbBorderWidth;
    [self setNeedsDisplay];
}

- (void)setTextSize:(float)textSize {
    _textSize = textSize;
    labelFont = [UIFont systemFontOfSize:textSize];
    [self setNeedsDisplay];
}

- (void)setLabelBorderWidth:(float)labelBorderWidth {
    _labelBorderWidth = labelBorderWidth;
    [self setNeedsDisplay];
}

- (void)setLabelPadding:(float)labelPadding {
    _labelPadding = labelPadding;
    [self setNeedsDisplay];
}

- (void)setLabelBorderRadius:(float)labelBorderRadius {
    if (labelBorderRadius < 0) {
        labelBorderRadius = 0;
    }
    _labelBorderRadius = labelBorderRadius;
    [self setNeedsDisplay];
}

- (void)setLabelTailHeight:(float)labelTailHeight {
    _labelTailHeight = labelTailHeight;
    [self setNeedsDisplay];
}

- (void)setLabelGapHeight:(float)labelGapHeight {
    _labelGapHeight = labelGapHeight;
    [self setNeedsDisplay];
}

- (void)setTextFormat:(NSString *)textFormat {
    _textFormat = textFormat;
    if ([_valueType isEqualToString:TYPE_TIME]) {
        [dateTimeFormatter setDateFormat:textFormat];
    }
    [self setNeedsDisplay];
}

- (void)setLabelStyle:(NSString *)labelStyle {
    _labelStyle = labelStyle;
    [self setNeedsDisplay];
}

- (void)setGravity:(NSString *)gravity {
    _gravity = @"TOP";
    [self setNeedsDisplay];
}

- (void)setRangeEnabled:(BOOL)rangeEnabled {
    _rangeEnabled = rangeEnabled;
    if (rangeEnabled) {
        if (_highValue < _lowValue) {
            _highValue = _lowValue;
        }
        if (_highValue > _max) {
            _highValue = _max;
        }
        if (_lowValue > _highValue) {
            _lowValue = _highValue;
        }
    }
    [self setNeedsDisplay];
}

-(void)setValueType:(NSString *)valueType {
    _valueType = valueType;
    if ([_valueType isEqualToString:TYPE_TIME]) {
        [dateTimeFormatter setDateFormat:_textFormat];
    }
}

- (void)setDisabled:(BOOL)disabled {
    _disabled = disabled;
    [self setNeedsDisplay];
}

- (void)setSelectionColor:(NSString *)selectionColor {
    _selectionColor = selectionColor;
    [self setNeedsDisplay];
}

- (void)setBlankColor:(NSString *)blankColor {
    _blankColor = blankColor;
    [self setNeedsDisplay];
}

- (void)setThumbColor:(NSString *)thumbColor {
    _thumbColor = thumbColor;
    [self setNeedsDisplay];
}

- (void)setThumbBorderColor:(NSString *)thumbBorderColor {
    _thumbBorderColor = thumbBorderColor;
    [self setNeedsDisplay];
}

- (void)setLabelBackgroundColor:(NSString *)labelBackgroundColor {
    _labelBackgroundColor = labelBackgroundColor;
    [self setNeedsDisplay];
}

- (void)setLabelTextColor:(NSString *)labelTextColor {
    _labelTextColor = labelTextColor;
    [self setNeedsDisplay];
}

- (void)setLabelBorderColor:(NSString *)labelBorderColor {
    _labelBorderColor = labelBorderColor;
    [self setNeedsDisplay];
}

- (void)setStep:(double)step {
    _step = step;
}

- (void)setMin:(double)min {
    if (min < _max) {
        _min = min;
        [self fitToMinMax];
    }
    [self setNeedsDisplay];
}

- (void)setMax:(double)max {
    if (max > _min) {
        _max = max;
        [self fitToMinMax];
    }
    [self setNeedsDisplay];
}


- (void)fitToMinMax {
    long long oldLow = _lowValue;
    long long oldHigh = _highValue;
    _lowValue = CLAMP(_lowValue, _min, _max);
    _highValue = CLAMP(_highValue, _min, _max);
    [self checkAndFireValueChangeEvent:oldLow oldHigh:oldHigh fromUser:false];
}

- (void)setInitialLowValue:(double)lowValue {
    if (!_initialLowValueSet) {
        _initialLowValueSet = true;
        [self setLowValue:lowValue];
    }
}

- (long long)minimumHandleSpace {
    CGFloat availableWidth = [self bounds].size.width - 2 * _thumbRadius;
    return (1 * _thumbRadius) * (_max - _min) / availableWidth;
}

- (void)setLowValue:(double)lowValue {
    [self setLowValue:lowValue fromUser:NO];
}

- (void)setLowValue:(double)lowValue fromUser:(BOOL)fromUser {
    long long oldLow = _lowValue;

    //Make sure low value doesnot overlap on the other thumb.
    _lowValue = CLAMP(lowValue, _min, (_rangeEnabled ? _highValue - _step : _max));
    
    [self checkAndFireValueChangeEvent:oldLow oldHigh:_highValue fromUser:fromUser];
    [self setNeedsDisplay];
}

- (void)setInitialHighValue:(double)highValue {
    if (!_initialHighValueSet) {
        _initialHighValueSet = true;
        [self setHighValue:highValue];
    }
}

- (void)setHighValue:(double)highValue {
    [self setHighValue:highValue fromUser:NO];
}

- (void)setHighValue:(double)highValue fromUser:(BOOL)fromUser {
    long long oldHigh = _highValue;
    
    //Make sure hight value doesnot overlap on the other thumb.
    _highValue = CLAMP(highValue, _lowValue + _step, _max);
    [self checkAndFireValueChangeEvent:_lowValue oldHigh:oldHigh fromUser:fromUser];
    [self setNeedsDisplay];
}

- (void)setMidValue:(double)midValue fromUser:(BOOL)fromUser {
    long long oldHigh = _highValue;
    long long oldLow = _lowValue;
    long long oldMid = (_highValue + _lowValue) / 2;
    long long dx = midValue - oldMid;
    CGFloat newHigh, newLow;
    if (dx > 0) { //moving right.
        newHigh = MIN(_max, oldHigh + dx);
        dx = newHigh - _highValue;
        newLow = _lowValue + dx;
    } else {
        newLow = MAX(_min, oldLow + dx);
        dx = newLow - _lowValue;
        newHigh = _highValue + dx;
    }
    if (dx == 0) {
        return;
    }
    _highValue = newHigh;
    _lowValue = newLow;
    [self checkAndFireValueChangeEvent:oldLow oldHigh:oldHigh fromUser:fromUser];
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (long long)getValueForPosition:(CGFloat)position {
    if (position <= _thumbRadius) {
        return _min;
    } else if (position >= [self bounds].size.width - _thumbRadius) {
        return _max;
    } else {
        CGFloat availableWidth = [self bounds].size.width - 2 * _thumbRadius;
        position -= _thumbRadius;
        long long relativePosition = (long long) ((_max - _min) * position / availableWidth);
        return _min + relativePosition - relativePosition % _step;
    }
}

- (void)checkAndFireValueChangeEvent:(long long)oldLow oldHigh:(long long)oldHigh fromUser:(BOOL)fromUser {
    if(!_delegate || (oldLow == _lowValue && oldHigh == _highValue) || _min == LONG_MIN || _max == LONG_MAX) {
        return;
    }

    [_delegate rangeSliderValueWasChanged:self fromUser:fromUser];
}

- (void)drawRect:(CGRect)rect {
    if (_min == LONG_MIN || _max == LONG_MAX) { // Min or max values have not been set yet
        return;
    }
    UIColor *blankColor = [RangeSlider colorWithHexString:_blankColor];
    UIColor *selectionColor = [RangeSlider colorWithHexString:_selectionColor];
    UIColor *labelBackgroundColor = [RangeSlider colorWithHexString:_labelBackgroundColor];
    UIColor *labelTextColor = [RangeSlider colorWithHexString:_labelTextColor];
    UIColor *labelBorderColor = [RangeSlider colorWithHexString:_labelBorderColor];

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetFontSize(context, _textSize);

    NSDictionary<NSAttributedStringKey, id> *labelTextAttributes = @{NSForegroundColorAttributeName: labelTextColor, NSFontAttributeName: labelFont};
    CGRect textRect = [@"0" boundingRectWithSize:CGSizeMake(500, 500) options:NSStringDrawingUsesLineFragmentOrigin attributes:labelTextAttributes context:nil];
    CGFloat labelTextHeight = textRect.size.height;
    BOOL isNoneStyle = [_labelStyle isEqualToString: NONE];
    CGFloat labelHeight = isNoneStyle ? 0 : 2 * _labelBorderWidth + _labelTailHeight + labelTextHeight + 2 * _labelPadding;

    CGFloat labelAndGapHeight = isNoneStyle ? 0 : labelHeight + _labelGapHeight;

    CGFloat drawingHeight = labelAndGapHeight + 2 * _thumbRadius;

    if (self.bounds.size.height > drawingHeight) {
        if ([_gravity isEqualToString: BOTTOM]) {
            CGContextTranslateCTM(context, 0, self.bounds.size.height - drawingHeight);
        } else if([_gravity isEqualToString: CENTER]) {
            CGContextTranslateCTM(context, 0, (self.bounds.size.height - drawingHeight) / 2);
        } else {
            CGContextTranslateCTM(context, 0, 5);
        }
    }

    CGFloat cy = labelAndGapHeight + _thumbRadius + _thumbRadius/2;

    CGFloat width = self.bounds.size.width;
    CGFloat availableWidth = width - 2 * _thumbRadius;

    // Draw the blank line
    CGContextAddRect(context, CGRectMake(_thumbRadius/2, cy - _lineWidth / 2, width - _thumbRadius, _lineWidth));
    [blankColor setFill];
    CGContextFillPath(context);
    
    // Draw notches at the edge
    UIGraphicsPushContext(context);
    CGContextSetLineWidth(context, 1.0);
    CGContextMoveToPoint(context, _thumbRadius/2, cy - _thumbRadius * 3 / 4);
    CGContextAddLineToPoint(context, _thumbRadius/2, cy + _thumbRadius * 3 / 4);
    CGContextMoveToPoint(context, width - _thumbRadius/2, cy - _thumbRadius * 3 / 4);
    CGContextAddLineToPoint(context, width - _thumbRadius/2, cy + _thumbRadius * 3 / 4);
    UIColor *thumbColor = [RangeSlider colorWithHexString:_thumbColor];
    [thumbColor setStroke];
    CGContextStrokePath(context);
    UIGraphicsPopContext();

    CGFloat lowX = _thumbRadius + availableWidth * (_lowValue - _min) / (_max - _min);
    CGFloat highX = _thumbRadius + availableWidth * (_highValue - _min) / (_max - _min);

    // Draw the selected line
    [selectionColor setStroke];
    if (_rangeEnabled) {
        CGContextMoveToPoint(context, lowX, cy);
        CGContextAddLineToPoint(context, highX, cy);
    } else {
        CGContextMoveToPoint(context, _thumbRadius, cy);
        CGContextAddLineToPoint(context, lowX, cy);
    }
    CGContextStrokePath(context);

//    if (_rangeEnabled && _highValue - _lowValue > 4 * [self minimumHandleSpace]) {
//        UIGraphicsPushContext(context);
//        CGFloat lowX = 3 * _thumbRadius + availableWidth * (_lowValue - _min) / (_max - _min);
//        CGFloat highX = - _thumbRadius + availableWidth * (_highValue - _min) / (_max - _min);
//        CGContextSetLineWidth(context, 5);
//        CGContextSetLineCap(context, kCGLineCapSquare);
//        CGContextMoveToPoint(context, lowX, cy);
//        CGContextAddLineToPoint(context, highX, cy);
//        CGContextStrokePath(context);
//        UIGraphicsPopContext();
//    }
    
    if (_thumbRadius > 0) {
        [self drawThumbAtX:lowX centerY:cy lineAtLeftEdge:YES context:context];
        if (_rangeEnabled) {
            [self drawThumbAtX:highX centerY:cy lineAtLeftEdge:NO context:context];
            [self drawScrollerAtY:3 * _thumbRadius  startX:lowX endX:highX context:context];
        }
    }

    if ([_labelStyle isEqualToString:NONE] || _activeThumb == THUMB_NONE) {
        return;
    }

    NSString *text = [self formatLabelText:_activeThumb == THUMB_LOW ? _lowValue : _highValue];
    textRect = [text boundingRectWithSize:CGSizeMake(500, 500) options:NSStringDrawingUsesLineFragmentOrigin attributes:labelTextAttributes context:nil];
    CGFloat labelTextWidth = textRect.size.width;
    CGFloat labelWidth = labelTextWidth + 2 * _labelPadding + 2 * _labelBorderWidth;
    CGFloat cx = _activeThumb == THUMB_LOW ? lowX : highX;

    if (labelWidth < _labelTailHeight / SQRT_3_2) {
        labelWidth = _labelTailHeight / SQRT_3_2;
    }

    CGFloat y = labelHeight;

    // Bounds of outer rectangular part
    CGFloat top = 0;
    CGFloat left = cx - labelWidth / 2;
    CGFloat right = left + labelWidth;
    CGFloat bottom = top + labelHeight - _labelTailHeight;
    CGFloat overflowOffset = 0;

    if (left < 0) {
        overflowOffset = -left;
    } else if (right > width) {
        overflowOffset = width - right;
    }

    left += overflowOffset;
    right += overflowOffset;
    [self preparePath:context x:cx y:y left:left top:top right:right bottom:bottom tailHeight:_labelTailHeight];
    [labelBorderColor setFill];
    CGContextFillPath(context);

    y = 2 * _labelPadding + labelTextHeight + _labelTailHeight;

    // Bounds of inner rectangular part
    top = _labelBorderWidth;
    left = cx - labelTextWidth / 2 - _labelPadding + overflowOffset;
    right = left + labelTextWidth + 2 * _labelPadding;
    bottom = _labelBorderWidth + 2 * _labelPadding + labelTextHeight;

    [self preparePath:context x:cx y:y left:left top:top right:right bottom:bottom tailHeight:_labelTailHeight - _labelBorderWidth];
    [labelBackgroundColor setFill];
    CGContextFillPath(context);

    CGContextSetFontSize(context, _textSize);
    [text drawAtPoint:CGPointMake(cx - labelTextWidth / 2 + overflowOffset, _labelBorderWidth + _labelPadding)
       withAttributes:labelTextAttributes];
    //CGContextShowTextAtPoint(context, cx - labelTextWidth / 2 + overflowOffset, _labelBorderWidth + _labelPadding, [text UTF8String], text.length);
}

- (void)drawThumbAtX:(CGFloat )x centerY:(CGFloat)cy lineAtLeftEdge:(BOOL)lineAtLeftEdge context:(CGContextRef)context {
    UIGraphicsPushContext(context);
    UIColor *thumbColor = [RangeSlider colorWithHexString:_thumbColor];
    UIColor *thumbBorderColor = [RangeSlider colorWithHexString:_thumbBorderColor];
    [thumbColor setFill];
    CGMutablePathRef pathRef = CGPathCreateMutable();
//    CGPathAddRect(pathRef, nil, CGRectMake(, cy - _thumbRadius * 3/4, _thumbRadius, _thumbRadius * 3 / 2));
    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColorWithColor(context, thumbBorderColor.CGColor);
    CGPathMoveToPoint(pathRef, nil, x - _thumbRadius/2, cy - _thumbRadius * 3/4);
    CGPathAddLineToPoint(pathRef, nil, x - _thumbRadius/2, cy + _thumbRadius * 3 / 4);
    CGPathAddLineToPoint(pathRef, nil, x + _thumbRadius/2, cy + _thumbRadius * 3 / 4);
    CGPathAddLineToPoint(pathRef, nil, x + _thumbRadius/2, cy - _thumbRadius * 3 / 4);
    CGPathAddLineToPoint(pathRef, nil, x , cy - _thumbRadius * 3 / 4 - _thumbRadius * 3 / 4);
    CGPathAddLineToPoint(pathRef, nil, x - _thumbRadius/2, cy - _thumbRadius * 3/4);
    CGContextAddPath(context, pathRef);
//    CGContextFillPath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    
    CGFloat lineX = lineAtLeftEdge ? x - _thumbRadius/2 : x + _thumbRadius/2;
    CGContextMoveToPoint(context, lineX, cy);
    CGContextAddLineToPoint(context, lineX, cy + 3 * _thumbRadius);
    CGContextStrokePath(context);
//    [thumbColor setFill];
//    CGContextAddArc(context, x, cy, _thumbRadius - _thumbBorderWidth, 0, M_PI * 2, true);
//    CGContextFillPath(context);
    UIGraphicsPopContext();
}

- (void)drawScrollerAtY:(CGFloat)y startX:(CGFloat)startX endX:(CGFloat)endX context:(CGContextRef)context {
    UIColor *blankColor = [RangeSlider colorWithHexString:_blankColor];
    UIGraphicsPushContext(context);
    [blankColor setFill];
    CGContextMoveToPoint(context, startX, y + _thumbRadius);
    CGRect rect = CGRectMake(startX, y, endX - startX, _thumbRadius * 2);
    CGContextAddRect(context, CGRectInset(rect, -_thumbRadius/2, 0));
    CGContextFillPath(context);
    CGFloat midX = (startX + endX) / 2;
    CGFloat midY = y + _thumbRadius;
    CGFloat dx = 3;
    CGContextMoveToPoint(context, startX -_thumbRadius/2, y + _thumbRadius);
    CGContextAddLineToPoint(context, startX -_thumbRadius/2, y + 3 * _thumbRadius);
    CGContextMoveToPoint(context, endX + _thumbRadius/2, y + _thumbRadius);
    CGContextAddLineToPoint(context, endX + _thumbRadius/2, y + 3 * _thumbRadius);
    CGContextMoveToPoint(context, midX - dx, midY - dx);
    CGContextAddLineToPoint(context, midX - dx, midY + dx);
    CGContextMoveToPoint(context, midX, midY - dx);
    CGContextAddLineToPoint(context, midX, midY + dx);
    CGContextMoveToPoint(context, midX + dx, midY - dx);
    CGContextAddLineToPoint(context, midX + dx, midY + dx);
    CGContextStrokePath(context);
    UIGraphicsPopContext();
}

- (void)preparePath:(CGContextRef)context x:(CGFloat)x y:(CGFloat)y left:(CGFloat)left top:(CGFloat)top right:(CGFloat)right bottom:(CGFloat)bottom tailHeight:(CGFloat)tailHeight {
    CGFloat cx = x;
    CGContextMoveToPoint(context, x, y);

    x = cx + tailHeight / SQRT_3;
    y = bottom;
    CGContextAddLineToPoint(context, x, y);
    x = right;
    CGContextAddLineToPoint(context, x, y);
    y = top;
    CGContextAddLineToPoint(context, x, y);
    x = left;
    CGContextAddLineToPoint(context, x, y);
    y = bottom;
    CGContextAddLineToPoint(context, x, y);
    x = cx - tailHeight / SQRT_3;
    CGContextAddLineToPoint(context, x, y);
    CGContextClosePath(context);
}

- (NSString *)formatLabelText:(long long)value {
    if ([_valueType isEqualToString:TYPE_NUMBER]) {
        return [NSString stringWithFormat:_textFormat, value];
    } else if ([_valueType isEqualToString:TYPE_TIME]) {
        return [dateTimeFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:(value / 1000)]];
    } else { // For other formatting methods, add cases here
        return @"";
    }
}

# pragma mark -
# pragma mark PanGestureHandling
- (void)_initiazeGestureRecognizer {
    self.pangestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.pangestureRecognizer.delegate = self;
    self.pangestureRecognizer.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:self.pangestureRecognizer];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        CGFloat y = [recognizer locationInView:self].y;
        long long pointerValue = [self getValueForPosition:[recognizer locationInView:self].x];
        if (_rangeEnabled && y > 3 * _thumbRadius) {
            _activeThumb = THUMB_MIDDLE;
        } else if (!_rangeEnabled ||
            (_lowValue == _highValue && pointerValue < _lowValue) ||
            ABS(pointerValue - _lowValue) < ABS(pointerValue - _highValue)) {
            _activeThumb = THUMB_LOW;
            [self setLowValue:pointerValue fromUser:YES];
        } else {
            _activeThumb = THUMB_HIGH;
            [self setHighValue:pointerValue fromUser:YES];
        }
        [_delegate rangeSliderTouchStarted:self];
        
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (_activeThumb == THUMB_MIDDLE) {
            long long pointerValue = [self getValueForPosition:[recognizer locationInView:self].x];
//            CGFloat availableWidth = [self bounds].size.width - 2 * _thumbRadius;
//            long long deltaValue = translation / availableWidth * (_max - _min);
//            if (ABS(deltaValue) > 0) {
//
//                if (translation < 0) {
//                    long long l = MAX(_min, _lowValue + deltaValue);
//                    [self setHighValue:l + _highValue - _lowValue fromUser:YES];
//                    [self setLowValue:l fromUser:YES];
//                } else {
//                    long long h = MIN(_max, _highValue + deltaValue);
//                    [self setLowValue:h - _highValue + _lowValue fromUser:YES];
//                    [self setHighValue:h fromUser:YES];
//                }
//                [recognizer setTranslation:CGPointZero inView:self];
//            }
            [self setMidValue:pointerValue fromUser:YES];
        } else {
            long long pointerValue = [self getValueForPosition:[recognizer locationInView:self].x];
            if (!_rangeEnabled) {
                _lowValue = pointerValue;
            } else if (_activeThumb == THUMB_LOW) {
                [self setLowValue:pointerValue fromUser:YES];
            } else if (_activeThumb == THUMB_HIGH) {
                [self setHighValue:pointerValue fromUser:YES];
            }
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) {
        _activeThumb = THUMB_NONE;
        [_delegate rangeSliderTouchEnded:self];
    }
    [self setNeedsDisplay];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.pangestureRecognizer) {
        UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;
        CGFloat xTranslation = [panGestureRecognizer translationInView:self].x;
        return (xTranslation >= 1 || xTranslation <= -1);
    }
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return !(_disabled || _min == LONG_MIN || _max == LONG_MAX);
}

@end