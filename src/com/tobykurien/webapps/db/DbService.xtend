package com.tobykurien.webapps.db

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import com.tobykurien.webapps.data.Webapp
import java.util.List
import org.xtendroid.db.BaseDbService

/**
 * Class to manage database queries. Uses Xtendroid's BaseDbService
 */
class DbService extends BaseDbService {
	public static val TABLE_WEBAPPS = "webapps"
	public static val TABLE_DOMAINS = "domain_names"

	protected new(Context context) {
		super(context, "webapps4", 2)
	}

	def static getInstance(Context context) {
		return new DbService(context)
	}

	override onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
		super.onUpgrade(db, oldVersion, newVersion)

		if (oldVersion == 1 && newVersion == 2) {
			db.execSQL('''alter table «TABLE_WEBAPPS» add column fontSize integer default -1''')
		}
	}

	def List<Webapp> getWebapps() {
		findAll(TABLE_WEBAPPS, "lower(name) asc", Webapp)
	}
}