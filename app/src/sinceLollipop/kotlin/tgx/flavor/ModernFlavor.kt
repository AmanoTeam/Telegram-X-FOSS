@file:JvmName("Flavor")
@file:JvmMultifileClass

package tgx.flavor

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.annotation.DrawableRes
import androidx.core.content.ContextCompat
import org.thunderdog.challegram.R
import org.thunderdog.challegram.widget.SwirlView

typealias Barcode = com.google.mlkit.vision.barcode.common.Barcode

typealias TgxApplication = Application

fun registerReceiver(
  context: Context,
  receiver: BroadcastReceiver,
  intentFilter: IntentFilter,
  isExported: Boolean
): Intent? {
  val flags = if (isExported) {
    ContextCompat.RECEIVER_EXPORTED
  } else {
    ContextCompat.RECEIVER_NOT_EXPORTED
  }
  return ContextCompat.registerReceiver(context, receiver, intentFilter, flags);
}

@DrawableRes
fun getSwirlDrawable(
  currentState: SwirlView.State,
  newState: SwirlView.State,
  animate: Boolean
): Int {
  return if (animate) {
    when (newState) {
      SwirlView.State.OFF ->
        when (currentState) {
          SwirlView.State.ON ->
            R.drawable.swirl_draw_off_animation
          SwirlView.State.ERROR ->
            R.drawable.swirl_error_off_animation
          else ->
            0
        }

      SwirlView.State.ON ->
        when (currentState) {
          SwirlView.State.OFF ->
            R.drawable.swirl_draw_on_animation
          SwirlView.State.ERROR ->
            R.drawable.swirl_error_state_to_fp_animation;
          else ->
            R.drawable.swirl_fingerprint
        }

      SwirlView.State.ERROR ->
        when (currentState) {
          SwirlView.State.ON ->
            R.drawable.swirl_fp_to_error_state_animation;
          SwirlView.State.OFF ->
            R.drawable.swirl_error_on_animation
          else ->
            R.drawable.swirl_error
        }
    }
  } else {
    when (newState) {
      SwirlView.State.OFF ->
        0
      SwirlView.State.ON ->
        R.drawable.swirl_fingerprint
      SwirlView.State.ERROR ->
        R.drawable.swirl_error
    }
  }
}
