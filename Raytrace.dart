import 'dart:io';
import 'dart:math';

import 'common/image.dart';
import 'common/jsonloader.dart';
import 'common/maths.dart';
import 'common/scene.dart';

var writeImageInBinary = true;
var overrideResolution = null; // Size2i(32, 32);
var overrideSamples    = null; // 1

List<String> scenePaths = [
    'scenes/P04_02_animation000.json',
    'scenes/P04_02_animation001.json',
    'scenes/P04_02_animation002.json',
    'scenes/P04_02_animation003.json',
    'scenes/P04_02_animation004.json',
    'scenes/P04_02_animation005.json',
    'scenes/P04_02_animation006.json',
    'scenes/P04_02_animation007.json',
    'scenes/P04_02_animation008.json',
    'scenes/P04_02_animation009.json',
    'scenes/P04_02_animation010.json',
    'scenes/P04_02_animation011.json',
    'scenes/P04_02_animation012.json',
    'scenes/P04_02_animation013.json',
    'scenes/P04_02_animation014.json',
    'scenes/P04_02_animation015.json',
    'scenes/P04_02_animation016.json',
    'scenes/P04_02_animation017.json',
    'scenes/P04_02_animation018.json',
    'scenes/P04_02_animation019.json',
    'scenes/P04_02_animation020.json',
    'scenes/P04_02_animation021.json',
    'scenes/P04_02_animation022.json',
    'scenes/P04_02_animation023.json',
    'scenes/P04_02_animation024.json',
    'scenes/P04_02_animation025.json',
    'scenes/P04_02_animation026.json',
    'scenes/P04_02_animation027.json',
    'scenes/P04_02_animation028.json',
    'scenes/P04_02_animation029.json',
    'scenes/P04_02_animation030.json',
    'scenes/P04_02_animation031.json',
    'scenes/P04_02_animation032.json',
    'scenes/P04_02_animation033.json',
    'scenes/P04_02_animation034.json',
    'scenes/P04_02_animation035.json',
    'scenes/P04_02_animation036.json',
    'scenes/P04_02_animation037.json',
    'scenes/P04_02_animation038.json',
    'scenes/P04_02_animation039.json',
    'scenes/P04_02_animation040.json',
    'scenes/P04_02_animation041.json',
    'scenes/P04_02_animation042.json',
    'scenes/P04_02_animation043.json',
    'scenes/P04_02_animation044.json',
    'scenes/P04_02_animation045.json',
    'scenes/P04_02_animation046.json',
    'scenes/P04_02_animation047.json',
];



// Determines if given ray intersects any surface in the scene.
// If ray does not intersect anything, null is returned.
// Otherwise, details of first intersection are returned as an `Intersection` object.
Intersection intersectRayScene(Scene scene, Ray ray) {
    Intersection intersection;
    var t_closest = double.infinity;

    for(var surface in scene.surfaces) {
        Point o = surface.frame.o;

        switch(surface.type) {
            case 'sphere': {
                Vector oe = ray.e - o;
                double a = ray.d.lengthSquared;
                double b = 2.0 * ray.d.dot(oe);
                double c = oe.lengthSquared - surface.size * surface.size;
                double d = b * b - 4 * a * c;
                if(d < 0) continue;     // ray misses sphere

                double sqrtd = sqrt(d);
                double t_min = (-b - sqrtd) / (2 * a);
                double t_max = (-b + sqrtd) / (2 * a);

                if(ray.valid(t_min) && t_min < t_closest) {
                    t_closest = t_min;
                    Point p = ray.eval(t_min);
                    Normal n = Normal.fromPoints(o, p);
                    Frame frame = Frame(o:p, n:n);
                    Normal nl = surface.frame.w2lNormal(n);
                    var theta = acos(nl.z);
                    var phi = atan2(nl.y,nl.x);
                    double u = ((phi/(pi))+1)/2;
                    double v = (theta/pi) ;
                    //print(u);
                    Vector2 uv = Vector2(u,v);
                    //print(surface.material.texture);
                    intersection = Intersection(frame, surface.material, t_closest, uv);
                }

                if(ray.valid(t_max) && t_max < t_closest) {
                    t_closest = t_max;
                    Point p = ray.eval(t_max);
                    Normal n = Normal.fromPoints(o, p);
                    Frame frame = Frame(o:p, n:n);
                    var theta = acos(n.z);
                    var phi = atan2(n.y,n.x);
                    double u = phi/(2*pi);
                    double v = (theta/pi) + (1/2);
                    Vector2 uv = Vector2(u,v);
                    intersection = Intersection(frame, surface.material, t_closest, uv);
                }
            } break;

            case 'quad': {
                double den = ray.d.dot(surface.frame.z);
                if(den.abs() <= 10e-8) continue;    // ray is parallel to plane
                double t = (o - ray.e).dot(surface.frame.z) / den;
                if(ray.valid(t) && t < t_closest) {
                    Point p = ray.eval(t);
                    // determine if p is inside quad
                    Point pl = surface.frame.w2lPoint(p);
                    if(pl.maxnorm > surface.size) continue;
                    t_closest = t;
                    Frame frame = Frame(o:p, x:surface.frame.x, y:surface.frame.y, z:surface.frame.z);
                    intersection = Intersection(frame, surface.material, t_closest, Vector2(0,0));
                }
            } break;
        }
    }

    for(var mesh in scene.meshes) {
        var ray_local = mesh.frame.w2lRay(ray); // transform ray to be local
        var el = ray_local.e;
        var dl = ray_local.d;

        // test if ray intersects bounding sphere
        double b = 2.0 * dl.dot(el);
        double c = el.lengthSquared - mesh.bssize * mesh.bssize;
        double d = b * b - 4.0 * c;
        if(d < 0.0) continue;     // ray misses sphere
        double sqrtd = sqrt(d);
        double t_min = (-b - sqrtd) / 2.0;
        double t_max = (-b + sqrtd) / 2.0;
        if(!ray.valid(t_min) && !ray.valid(t_max)) continue;

        for(var i_face = 0; i_face < mesh.faces.length; i_face += 3) {
            // https://gfx.cse.taylor.edu/courses/cos350/slides/03_Raytracing.md.html?scale#sect029
            var a = mesh.verts[mesh.faces[i_face+0]];
            var b = mesh.verts[mesh.faces[i_face+1]];
            var c = mesh.verts[mesh.faces[i_face+2]];
            var a_ = a  - c;    // a'
            var b_ = b  - c;    // b'
            var e_ = el - c;    // e'
            var t     = e_.cross(a_).dot(b_) / dl.cross(b_).dot(a_);
            var alpha = dl.cross(b_).dot(e_) / dl.cross(b_).dot(a_);
            var beta  = e_.cross(a_).dot(dl) / dl.cross(b_).dot(a_);
            var gamma = 1.0 - alpha - beta;
            if(!ray_local.valid(t) || t >= t_closest) continue;
            if(alpha < 0 || beta < 0 || alpha + beta >= 1) continue;
            t_closest = t;
            Point  pl = ray_local.eval(t);
            Normal nl = Normal.fromVector(
                mesh.norms[mesh.faces[i_face+0]] * alpha +
                mesh.norms[mesh.faces[i_face+1]] * beta  +
                mesh.norms[mesh.faces[i_face+2]] * gamma
            );
            Vector2 uvs = 
                mesh.uvs[mesh.faces[i_face+0]] * alpha +
                mesh.uvs[mesh.faces[i_face+1]] * beta  +
                mesh.uvs[mesh.faces[i_face+2]] * gamma;
            Frame frame = Frame(o:mesh.frame.l2wPoint(pl), n:mesh.frame.l2wNormal(nl));
            intersection = Intersection(frame, mesh.material, t_closest, uvs);
        }
    }

    return intersection;
}

// Computes irradiance (as RGBColor) from scene along ray
RGBColor irradiance(Scene scene, Ray ray, int depth) {
    Intersection intersection = intersectRayScene(scene, ray);
    if(intersection == null) return scene.backgroundIntensity;
    if(depth <= 0) return RGBColor.black();
    RGBColor  kd = intersection.material.kd;
    //print(intersection.material.texture);
    if(intersection.material.texture != null){
        //print("Here!");
        var textureWidth = intersection.material.texture.width;
        var textureHeight = intersection.material.texture.height;
        kd = RGBColor.fromColor(intersection.material.texture.getPixel(intersection.uvs.x*(textureWidth-1),intersection.uvs.y*(textureHeight-1)));
    }

    Point     p  = intersection.o;
    Direction v  = -ray.d;
    RGBColor  ks = intersection.material.ks;
    double    n  = intersection.material.n;
    RGBColor  kr = intersection.material.kr;

    // start accumulating irradiance
    RGBColor c = kd * scene.ambientIntensity;

    for(var light in scene.lights) {
        Vector ps = light.frame.o - p;
        double dist = ps.length;
        Direction l = Direction.fromVector(ps);
        Ray shadowRay = Ray(p, l, t_max:dist);
        if(intersectRayScene(scene, shadowRay) != null) continue;
        Direction h = Direction.fromVector(l + v);
        RGBColor L = light.intensity / (dist * dist);
        c += L * (kd + ks * pow(max(0, intersection.n.dot(h)), n) ) * max(intersection.n.dot(l), 0.0);
    }

    if(!kr.isBlack) {
        Direction r = v.reflected(intersection.frame.z);
        Ray reflectRay = Ray(p, r);
        RGBColor rc = irradiance(scene, reflectRay, depth-1);
        c += kr * rc;
    }

    return c;
}

// Computes image of scene using basic Whitted raytracer.
Image raytraceScene(Scene scene) {
    var image = Image(scene.resolution.width, scene.resolution.height);

    Frame cameraFrame = scene.camera.frame;
    int samples = max(Num.sqrtInt(scene.pixelSamples), 1);
    for(var x = 0; x < scene.resolution.width; x++) {
        for(var y = 0; y < scene.resolution.height; y++) {
            RGBColor c = RGBColor.black();
            for(var ii = 0; ii < samples; ii++) {
                for(var jj = 0; jj < samples; jj++) {
                    double u = (x + (ii + 0.5) / samples) / scene.resolution.width;
                    double v = 1.0 - (y + (jj + 0.5) / samples) / scene.resolution.height;
                    Point o = cameraFrame.o;
                    Point q = o
                        + cameraFrame.x * (scene.camera.sensorSize.width  * (u - 0.5))
                        + cameraFrame.y * (scene.camera.sensorSize.height * (v - 0.5))
                        + cameraFrame.z * -scene.camera.sensorDistance;
                    Ray camera_ray = Ray(o, Direction.fromPoints(o, q));
                    c += irradiance(scene, camera_ray, 5);
                }
            }
            c /= samples * samples;
            image.setPixel(x, y, c);
        }
    }

    return image;
}

void main() {
    // Make sure images folder exists, because this is where all generated images will be saved
    Directory('images').createSync();

    for(String scenePath in scenePaths) {
        // Determine where to write the rendered image.
        // NOTE: the following line is not safe, but it is fine for this project.
        var ppmPath = scenePath.replaceAll('.json', '.ppm').replaceAll('scenes/', 'images/');

        print('Scene: $scenePath');
        print('    output image: $ppmPath');
        print('    loading...');
        var loader = JsonLoader(path:scenePath);    // load json file
        var scene = Scene.fromJson(loader);         // parse json file as Scene

        // override scene's resolution
        if(overrideResolution != null) {
            print('    overriding resolution: $overrideResolution');
            scene.resolution = overrideResolution;
        }
        if(overrideSamples != null) {
            print('    overriding pixelSamples: $overrideSamples');
            scene.pixelSamples = overrideSamples;
        }

        print('    tracing rays...');
        Stopwatch watch = Stopwatch()..start();             // create Stopwatch, then start it (NOTE: keep the two ..)
        var image = raytraceScene(scene);                   // raytrace the scene
        var seconds = watch.elapsedMilliseconds / 1000.0;   // determine elapsed time in seconds

        image.saveImage(ppmPath, asBinary:writeImageInBinary);  // write raytraced image to PPM file

        // report details to console
        print('    time:  $seconds seconds');               // note: includes time for saving file
    }
}
