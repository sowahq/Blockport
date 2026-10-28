import Foundation
import ObjectiveC

/// Replaces the implementation of an Objective-C instance method.
enum MethodReplacement {
    /// Installs `block` as the implementation of `selector` on `targetClass`
    /// and returns the implementation it replaces, or `nil` when neither the
    /// class nor its ancestors implement the selector. A method inherited
    /// from a superclass is overridden on `targetClass` only, so other
    /// subclasses keep their behaviour. The block takes the receiver followed
    /// by the method's arguments, without `_cmd`.
    @discardableResult
    static func replace(_ selector: Selector, on targetClass: AnyClass, with block: Any) -> IMP? {
        guard let method = class_getInstanceMethod(targetClass, selector) else {
            Trace.event("runtime", "\(targetClass) has no \(selector)")
            return nil
        }
        let implementation = imp_implementationWithBlock(block)
        let inherited = method_getImplementation(method)
        if class_addMethod(targetClass, selector, implementation, method_getTypeEncoding(method)) {
            return inherited
        }
        return method_setImplementation(method, implementation)
    }
}
