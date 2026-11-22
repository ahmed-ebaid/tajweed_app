# Room instantiates generated databases (WorkManager's WorkDatabase_Impl, pulled in
# by the Quran Lab SDK) through reflection; R8 full mode drops the constructor
# unless it is kept explicitly, which crashes the app at launch.
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# WorkManager instantiates input mergers and workers (including the Quran Lab
# SDK's model download, delivery and outbox workers) by reflection.
-keep class * extends androidx.work.InputMerger { <init>(); }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
