echo '<package name="com.google.android.youtube" codePath="/data/app/~~uU0m==/com.google.android.youtube-abc==">' | grep -o 'package name="com.google.android.youtube" codePath="[^"]*' | cut -d'"' -f4
