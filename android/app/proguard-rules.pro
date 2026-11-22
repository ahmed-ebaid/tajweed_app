# Room instantiates generated databases (WorkManager's WorkDatabase_Impl, pulled in
# by the Quran Lab SDK) through reflection; R8 full mode drops the constructor
# unless it is kept explicitly, which crashes the app at launch.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
