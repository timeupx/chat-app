/// Tracks a viewer's own "request to be guest" so the button reflects
/// reality instead of allowing the same request to be spammed forever:
/// tap once -> `pending` ("Requested", disabled) -> either the host
/// accepts (screen moves on to becoming a guest) or declines ->
/// `rejected` ("Rejected") -> resets back to `none` after a short delay so
/// they can try again. Shared by [ViewerScreen] and [SwipeableLiveScreen].
enum GuestRequestStatus { none, pending, rejected }
