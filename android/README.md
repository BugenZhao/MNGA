# Android Examples

## Compile Logic Library

1. Install Rust toolchains and `protoc`
2. In project's root directory, run

   ```bash
   make kotlin-pb
   make logic-release-android
   ```

   Follow the instructions from the output of commands above to install missing components, if any.

You should see generated Kotlin sources under `android/.../protos/`, and dynamic-linked libraries for JNI under `out/libs/jniLibs/`.

## Prepare Android Project

### Create a Android module named `logic`

Put output files from last step into their places. Your project structure should look like the following:

```
logic
├── build.gradle
└── src
    ├── main
    │   ├── AndroidManifest.xml
    │   ├── java
    │   │   └── com.bugenzhao.nga
    │   │      ├── protos
    │   │      └── logic.kt
    │   └── jniLibs
    │       ├── arm64-v8a
    │       ├── x86
    │       └── x86_64
    └── test
        └── java

```

You may check `logic.kt` for an example of logic wrapper and usage to the logic interfaces.

### In module-level `build.gradle`

```groovy
dependencies {
    implementation ('com.google.protobuf:protobuf-kotlin:3.17.0') {
        exclude group: "com.google.protobuf", module: "protobuf-java"
    }
}
```

### In project-level `build.gradle`

```groovy
dependencies {
    classpath 'com.google.protobuf:protobuf-gradle-plugin:0.8.17'
}
```
