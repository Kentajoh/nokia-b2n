/* Freestanding bionic shims so hybris android_dlopen succeeds.
 * Real HAL wiring needs a hybris-hal build; these return "unavailable"
 * instead of leaving a NULL handle that SIGSEGVs the glibc wrapper.
 */
#define EXPORT __attribute__((visibility("default")))

EXPORT int android_camera_get_number_of_devices(void) { return 0; }
EXPORT void *android_camera_connect_to(int type, void *listener)
{
    (void)type;
    (void)listener;
    return 0;
}
EXPORT void *android_camera_connect_by_id(int id, void *listener)
{
    (void)id;
    (void)listener;
    return 0;
}
EXPORT void android_camera_disconnect(void *c) { (void)c; }
EXPORT int android_camera_lock(void *c)
{
    (void)c;
    return -1;
}
EXPORT int android_camera_unlock(void *c)
{
    (void)c;
    return -1;
}
EXPORT void android_camera_delete(void *c) { (void)c; }
EXPORT void android_camera_set_display_orientation(void *c, int d)
{
    (void)c;
    (void)d;
}
EXPORT void android_camera_set_preview_texture(void *c, int id)
{
    (void)c;
    (void)id;
}
EXPORT void android_camera_get_preview_texture_transformation(void *c, float *m)
{
    (void)c;
    (void)m;
}
EXPORT void android_camera_update_preview_texture(void *c) { (void)c; }
EXPORT void android_camera_set_preview_surface(void *c, void *s)
{
    (void)c;
    (void)s;
}
EXPORT void android_camera_start_preview(void *c) { (void)c; }
EXPORT void android_camera_stop_preview(void *c) { (void)c; }
EXPORT void android_camera_start_autofocus(void *c) { (void)c; }
EXPORT void android_camera_stop_autofocus(void *c) { (void)c; }
EXPORT void android_camera_start_zoom(void *c, int z)
{
    (void)c;
    (void)z;
}
EXPORT void android_camera_stop_zoom(void *c) { (void)c; }
EXPORT void android_camera_set_zoom(void *c, int z)
{
    (void)c;
    (void)z;
}
EXPORT void android_camera_take_snapshot(void *c) { (void)c; }
EXPORT int android_camera_set_preview_callback_mode(void *c, int mode)
{
    (void)c;
    (void)mode;
    return -1;
}
EXPORT void android_camera_dump_parameters(void *c, void *out)
{
    (void)c;
    (void)out;
}
EXPORT void android_camera_enumerate_supported_flash_modes(void *c, void *cb, void *ctx)
{
    (void)c;
    (void)cb;
    (void)ctx;
}
EXPORT void android_camera_enumerate_supported_picture_sizes(void *c, void *cb, void *ctx)
{
    (void)c;
    (void)cb;
    (void)ctx;
}
EXPORT void android_camera_enumerate_supported_preview_sizes(void *c, void *cb, void *ctx)
{
    (void)c;
    (void)cb;
    (void)ctx;
}
EXPORT void android_camera_enumerate_supported_scene_modes(void *c, void *cb, void *ctx)
{
    (void)c;
    (void)cb;
    (void)ctx;
}
EXPORT void android_camera_enumerate_supported_thumbnail_sizes(void *c, void *cb, void *ctx)
{
    (void)c;
    (void)cb;
    (void)ctx;
}
EXPORT void android_camera_enumerate_supported_video_sizes(void *c, void *cb, void *ctx)
{
    (void)c;
    (void)cb;
    (void)ctx;
}
EXPORT int android_camera_get_auto_focus_mode(void *c, void *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_device_info(int id, void *out)
{
    (void)id;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_effect_mode(void *c, void *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_flash_mode(void *c, void *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_jpeg_quality(void *c, void *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_max_zoom(void *c, int *out)
{
    (void)c;
    if (out)
        *out = 0;
    return -1;
}
EXPORT int android_camera_get_picture_size(void *c, int *w, int *h)
{
    (void)c;
    if (w)
        *w = 0;
    if (h)
        *h = 0;
    return -1;
}
EXPORT int android_camera_get_preview_fps(void *c, int *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_preview_fps_range(void *c, int *min, int *max)
{
    (void)c;
    (void)min;
    (void)max;
    return -1;
}
EXPORT int android_camera_get_preview_size(void *c, int *w, int *h)
{
    (void)c;
    if (w)
        *w = 0;
    if (h)
        *h = 0;
    return -1;
}
EXPORT int android_camera_get_scene_mode(void *c, void *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_get_thumbnail_size(void *c, int *w, int *h)
{
    (void)c;
    (void)w;
    (void)h;
    return -1;
}
EXPORT int android_camera_get_video_size(void *c, int *w, int *h)
{
    (void)c;
    (void)w;
    (void)h;
    return -1;
}
EXPORT int android_camera_get_white_balance_mode(void *c, void *out)
{
    (void)c;
    (void)out;
    return -1;
}
EXPORT int android_camera_reset_focus_region(void *c)
{
    (void)c;
    return -1;
}
EXPORT int android_camera_reset_metering_region(void *c)
{
    (void)c;
    return -1;
}
EXPORT int android_camera_set_auto_focus_mode(void *c, int mode)
{
    (void)c;
    (void)mode;
    return -1;
}
EXPORT int android_camera_set_effect_mode(void *c, int mode)
{
    (void)c;
    (void)mode;
    return -1;
}
EXPORT int android_camera_set_flash_mode(void *c, int mode)
{
    (void)c;
    (void)mode;
    return -1;
}
EXPORT int android_camera_set_focus_region(void *c, void *r)
{
    (void)c;
    (void)r;
    return -1;
}
EXPORT int android_camera_set_jpeg_quality(void *c, int q)
{
    (void)c;
    (void)q;
    return -1;
}
EXPORT int android_camera_set_location(void *c, void *loc)
{
    (void)c;
    (void)loc;
    return -1;
}
EXPORT int android_camera_set_metering_region(void *c, void *r)
{
    (void)c;
    (void)r;
    return -1;
}
EXPORT int android_camera_set_picture_size(void *c, int w, int h)
{
    (void)c;
    (void)w;
    (void)h;
    return -1;
}
EXPORT int android_camera_set_preview_format(void *c, int fmt)
{
    (void)c;
    (void)fmt;
    return -1;
}
EXPORT int android_camera_set_preview_fps(void *c, int fps)
{
    (void)c;
    (void)fps;
    return -1;
}
EXPORT int android_camera_set_preview_size(void *c, int w, int h)
{
    (void)c;
    (void)w;
    (void)h;
    return -1;
}
EXPORT int android_camera_set_rotation(void *c, int r)
{
    (void)c;
    (void)r;
    return -1;
}
EXPORT int android_camera_set_scene_mode(void *c, int mode)
{
    (void)c;
    (void)mode;
    return -1;
}
EXPORT int android_camera_set_thumbnail_size(void *c, int w, int h)
{
    (void)c;
    (void)w;
    (void)h;
    return -1;
}
EXPORT int android_camera_set_video_size(void *c, int w, int h)
{
    (void)c;
    (void)w;
    (void)h;
    return -1;
}
EXPORT int android_camera_set_white_balance_mode(void *c, int mode)
{
    (void)c;
    (void)mode;
    return -1;
}

EXPORT int media_compat_check_availability(void) { return 0; }
EXPORT unsigned hybris_media_get_version(void) { return 1; }
EXPORT void android_media_set_video_size_cb(void *mp, void *cb, void *ctx)
{
    (void)mp;
    (void)cb;
    (void)ctx;
}
EXPORT void android_media_set_video_texture_needs_update_cb(void *mp, void *cb, void *ctx)
{
    (void)mp;
    (void)cb;
    (void)ctx;
}
EXPORT void android_media_set_error_cb(void *mp, void *cb, void *ctx)
{
    (void)mp;
    (void)cb;
    (void)ctx;
}
EXPORT void android_media_set_playback_complete_cb(void *mp, void *cb, void *ctx)
{
    (void)mp;
    (void)cb;
    (void)ctx;
}
EXPORT void android_media_set_media_prepared_cb(void *mp, void *cb, void *ctx)
{
    (void)mp;
    (void)cb;
    (void)ctx;
}
EXPORT void *android_media_new_player(void) { return 0; }
EXPORT void *android_media_new_recorder(void) { return 0; }
EXPORT void *android_media_recorder_observer_new(void) { return 0; }
EXPORT void android_media_recorder_observer_set_cb(void *obs, void *cb, void *ctx)
{
    (void)obs;
    (void)cb;
    (void)ctx;
}
EXPORT int android_media_set_data_source(void *mp, const char *url)
{
    (void)mp;
    (void)url;
    return -1;
}
EXPORT int android_media_set_preview_texture(void *mp, int id)
{
    (void)mp;
    (void)id;
    return -1;
}
EXPORT void android_media_update_surface_texture(void *mp) { (void)mp; }
EXPORT void android_media_surface_texture_get_transformation_matrix(void *mp, float *m)
{
    (void)mp;
    (void)m;
}
EXPORT int android_media_play(void *mp)
{
    (void)mp;
    return -1;
}
EXPORT int android_media_pause(void *mp)
{
    (void)mp;
    return -1;
}
EXPORT int android_media_stop(void *mp)
{
    (void)mp;
    return -1;
}
EXPORT int android_media_is_playing(void *mp)
{
    (void)mp;
    return 0;
}
EXPORT int android_media_seek_to(void *mp, int msec)
{
    (void)mp;
    (void)msec;
    return -1;
}
EXPORT int android_media_get_current_position(void *mp, int *msec)
{
    (void)mp;
    if (msec)
        *msec = 0;
    return -1;
}
EXPORT int android_media_get_duration(void *mp, int *msec)
{
    (void)mp;
    if (msec)
        *msec = 0;
    return -1;
}
EXPORT int android_media_get_volume(void *mp, int *vol)
{
    (void)mp;
    if (vol)
        *vol = 0;
    return -1;
}
EXPORT int android_media_set_volume(void *mp, int vol)
{
    (void)mp;
    (void)vol;
    return -1;
}

EXPORT int android_input_check_availability(void) { return 0; }
EXPORT void android_input_stack_initialize(void *l, void *c)
{
    (void)l;
    (void)c;
}
EXPORT void android_input_stack_loop_once(void) {}
EXPORT void android_input_stack_start(void) {}
EXPORT void android_input_stack_start_waiting_for_flag(int *flag) { (void)flag; }
EXPORT void android_input_stack_stop(void) {}
EXPORT void android_input_stack_shutdown(void) {}

EXPORT void hybris_sf_initialize(void) {}
EXPORT void sf_blank(unsigned long id) { (void)id; }
EXPORT void sf_unblank(unsigned long id) { (void)id; }
EXPORT unsigned long sf_get_display_width(unsigned long id)
{
    (void)id;
    return 1080;
}
EXPORT unsigned long sf_get_display_height(unsigned long id)
{
    (void)id;
    return 2160;
}
EXPORT unsigned long sf_get_display_info(unsigned long id, void *info)
{
    (void)id;
    (void)info;
    return 0;
}
EXPORT void *sf_client_create_full(int egl)
{
    (void)egl;
    return 0;
}
EXPORT void *sf_client_create(void) { return 0; }
EXPORT void *sf_client_get_egl_display(void *c)
{
    (void)c;
    return 0;
}
EXPORT void *sf_client_get_egl_config(void *c)
{
    (void)c;
    return 0;
}
EXPORT void *sf_client_get_egl_context(void *c)
{
    (void)c;
    return 0;
}
EXPORT void sf_client_begin_transaction(void *c) { (void)c; }
EXPORT void sf_client_end_transaction(void *c) { (void)c; }
EXPORT void *sf_surface_create(void *c, void *p)
{
    (void)c;
    (void)p;
    return 0;
}
EXPORT void *sf_surface_get_egl_surface(void *s)
{
    (void)s;
    return 0;
}
EXPORT void *sf_surface_get_egl_native_window(void *s)
{
    (void)s;
    return 0;
}
EXPORT void sf_surface_make_current(void *s) { (void)s; }
EXPORT void sf_surface_move_to(void *s, int x, int y)
{
    (void)s;
    (void)x;
    (void)y;
}
EXPORT void sf_surface_set_size(void *s, int w, int h)
{
    (void)s;
    (void)w;
    (void)h;
}
EXPORT void sf_surface_set_layer(void *s, int layer)
{
    (void)s;
    (void)layer;
}
EXPORT void sf_surface_set_alpha(void *s, float a)
{
    (void)s;
    (void)a;
}
