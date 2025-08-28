// android/build.gradle

buildscript {
    // 使用するKotlinのバージョンを指定します
    ext.kotlin_version = '1.9.23'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Androidのビルドツールのバージョンを指定します
        classpath 'com.android.tools.build:gradle:8.2.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}

// android/build.gradle の一番下に追加

subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            android {
                compileSdkVersion 34
            }
        }
    }
}