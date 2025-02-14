package com.valentingrigorean.arcgis_maps_flutter;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Lifecycle;

import com.esri.arcgisruntime.ArcGISRuntimeEnvironment;
import com.esri.arcgisruntime.LicenseResult;
import com.valentingrigorean.arcgis_maps_flutter.authentication.AuthenticationManagerController;
import com.valentingrigorean.arcgis_maps_flutter.flutterobject.ArcgisNativeObjectFactoryImpl;
import com.valentingrigorean.arcgis_maps_flutter.flutterobject.ArcgisNativeObjectsController;
import com.valentingrigorean.arcgis_maps_flutter.geometry.CoordinateFormatterController;
import com.valentingrigorean.arcgis_maps_flutter.geometry.GeometryEngineController;
import com.valentingrigorean.arcgis_maps_flutter.map.ArcgisMapFactory;
import com.valentingrigorean.arcgis_maps_flutter.scene.ArcgisSceneViewFactory;
import com.valentingrigorean.arcgis_maps_flutter.service_table.ServiceTableController;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * ArcgisMapsFlutterPlugin
 */
public class ArcgisMapsFlutterPlugin implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    final static String TAG = "ArcgisMapsFlutterPlugin";

    private static final String VIEW_TYPE_MAP = "plugins.flutter.io/arcgis_maps";
    private static final String VIEW_TYPE_SCENE = "plugins.flutter.io/arcgis_scene";

    private GeometryEngineController geometryEngineController;
    private CoordinateFormatterController coordinateFormatterController;
    private ArcgisNativeObjectsController nativeObjectsController;
    private MethodChannel channel;

    private ServiceTableController serviceTableController;

    private AuthenticationManagerController authenticationManagerController;

    @Nullable
    private Lifecycle lifecycle;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        binding.getPlatformViewRegistry()
                .registerViewFactory(VIEW_TYPE_MAP, new ArcgisMapFactory(binding.getBinaryMessenger(), () -> lifecycle));

        binding.getPlatformViewRegistry()
                .registerViewFactory(VIEW_TYPE_SCENE, new ArcgisSceneViewFactory(binding.getBinaryMessenger(), () -> lifecycle));

        channel = new MethodChannel(binding.getBinaryMessenger(), "plugins.flutter.io/arcgis_channel");
        channel.setMethodCallHandler(this);

        geometryEngineController = new GeometryEngineController(binding.getBinaryMessenger());

        coordinateFormatterController = new CoordinateFormatterController(binding.getBinaryMessenger());

        nativeObjectsController = new ArcgisNativeObjectsController(binding.getBinaryMessenger(), new ArcgisNativeObjectFactoryImpl(binding.getApplicationContext()));

        serviceTableController = new ServiceTableController(binding.getBinaryMessenger());

        authenticationManagerController = new AuthenticationManagerController(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        geometryEngineController.dispose();
        geometryEngineController = null;

        coordinateFormatterController.dispose();
        coordinateFormatterController = null;

        nativeObjectsController.dispose();
        nativeObjectsController = null;

        serviceTableController.dispose();
        serviceTableController = null;

        authenticationManagerController.dispose();
        authenticationManagerController = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        lifecycle = getActivityLifecycle(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        lifecycle = null;
    }

    @NonNull
    private static Lifecycle getActivityLifecycle(
            @NonNull ActivityPluginBinding activityPluginBinding) {
        HiddenLifecycleReference reference =
                (HiddenLifecycleReference) activityPluginBinding.getLifecycle();
        return reference.getLifecycle();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "arcgis#setApiKey":
                final String apiKey = call.arguments();
                ArcGISRuntimeEnvironment.setApiKey(apiKey);
                Log.d(TAG, "setApiKey: " + apiKey);
                result.success(null);
                break;
            case "arcgis#getApiKey":
                result.success(ArcGISRuntimeEnvironment.getApiKey());
                break;
            case "arcgis#setLicense":
                final String licenseKey = call.arguments();
                final LicenseResult licenseResult = ArcGISRuntimeEnvironment.setLicense(licenseKey);
                Log.d(TAG, "setLicense: " + licenseKey);
                Log.d(TAG, "licenseResult: " + licenseResult.getLicenseStatus());
                result.success(licenseResult.getLicenseStatus().ordinal());
                break;
            case "arcgis#getApiVersion":
                result.success(ArcGISRuntimeEnvironment.getAPIVersion());
                break;
        }
    }
}
