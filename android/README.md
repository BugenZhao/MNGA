## In module-level `build.gradle`
```groovy
dependencies {
    implementation ('com.google.protobuf:protobuf-kotlin:3.17.0') {
        exclude group: "com.google.protobuf", module: "protobuf-java"
    }
}
```

## In project-level `build.gradle`
```groovy
dependencies {
    classpath 'com.google.protobuf:protobuf-gradle-plugin:0.8.17'
}
```
