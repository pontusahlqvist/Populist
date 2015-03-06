/*
TODO:
- Change future infinity to queried time (as long as valid until after the time for which it's queries all should be ok - think historically)
- look into ACL
- improve the ordering of contributions (e.g. compare global events to local events)
- change get contribution Ids in cluster to something that only returns the ones since the last pull. Do this by also including a timestamp in the query.
- set up AWS for storing contributions
- make sure google api is set up correctly with payment info since the free tier only allows for 20k requests per day...
- when merging compute spatial and temporal separately in order to maximize the probability
- make sure success/error is called correctly
- (iOS side) should probably either move all the location data calls to the ios side or at least make sure location has changed sufficiently before re-calling it (otherwise it will likely be called each time the user goes back to the main view etc)
- Make sure merging also merged title images
- send along some info when a merge happens to allow the client side to handle the merge smoothly


DONE:
- include userId in clustering so that a given user who is already part of a given event will be able to contribute farther away / later - DONE
- make sure flagged contributions don't appear as title contributions (do this by also sending along the clusterId in the flagContribution call) - DONE
- create a dedicated "flagContribution" function that can be called from anywhere - DONE
*/



///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////     GLOBAL VARIABLES       ///////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

var defaultImageId = "oN074BoUba";
var futureInfinity = new Date("December 31, 2100 23:59:59"); //representative of infinite future. Intended to show active vs. inactive clusters

/*new variables for improved algorithm*/
//time related parameters
//old values prior to 7/24/2014
//var alpha = 2.2345
//var beta = 2234.5
/*Note, alpha = (tau_avg/delta_tau)^2 + 1 and beta = alpha*tau_avg 
where tau_avg is the average event length and delta_tau is the uncertainty in the event length.
In this case we choose tau_avg = 4000 sec ~ 1+ hour and delta_tau = 3000 sec. This places the event length between 1000 sec and 7000 sec,
i.e. on the scale of a few minutes to a couple of hours. Note that all the time scales in the algorithm are measured in seconds.
*/
var alpha = 2.77777
var beta = 11111.1
//space related parameter
var alpha0 = 1.4489501
var beta0 = 0.000073628
//adding to cluster parameters
var thresholdToAdd = 0.002; //originally 0.003, but decreased to increase likelyhood of adding.
//var multiplier = 1.0; //the issue with setting this to something other than 1 is that if two nearby photos create two separate clusters, other photos will always start their own clusters.
//merge two clusters parameters
//var mergeThresholdSpace = 3.0;
//var mergeThresholdTime = 0.01;
var thresholdToMerge = thresholdToAdd;
//space and time cutoffs to avoid having to look through too many clusters.
var minuteCutoffAdd = 60*2; // default 120
var minuteCutoffMerge = 60*1;

//var minuteCutoffGetLocal = 1;
//var minuteCutoffGetGlobal = 1;
var minuteCutoffGetLocal = 60*24*7*10;//60*24*7;
var minuteCutoffGetGlobal = 60*24*7*10;//60*24*7;

var maxMilesToAdd = 1;
var maxMilesToMerge = maxMilesToAdd;
//parameters for retrieving clusters
var minLocalFitValue = 1.0;
var minGlobalFitValue = 1.0;
//local stuff
var localGettingMilesCutoff = 10;
var typicalDistanceForGettingLocal = 10;
//var secondDecayForLocalGetting = 60;
var secondDecayForLocalGetting = 60*60*24*7*10;//60*60*8; //typical time decay for finding a nearby cluster (since last update).

//global stuff
//var secondDecayForGlobalGetting = 60;
var secondDecayForGlobalGetting = 60*60*24*7*10; //60*60*24;

var globalImportanceThreshold = 2; //this will have to start out small and increase over time as more people join the service.

/*powerUsers are userIds which are allowed to artificially inflate the importance of an event.*/
var powerUsers = ["temporaryUserId"];
var maxUserCountToIterate = 1000; //sets the number of users to iterate through to determine the importance reduction. After 1000 users, we don't loop through them since it would be very expensive

///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// DATA MANIPULATION METHODS  ///////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
This method is called after a new photo is inserted into the database. It will add the photo to the appropriate cluster if one exists or create a new one when appropriate. If it 
adds the photo to an already existing cluster, it will ask once to see if it should be merged into another cluster. If this is the case, it will perform the merge.
*/
Parse.Cloud.afterSave("Contribution", function(request){
    var reSaved = request.object.get("reSaved");
    //only if reSaved != 1 do we do any clustering etc. Otherwise, we just allow the contribution to be reSaved.
    if(reSaved != 1){
        
        /*****  retrieve the data from the object  *****/
        var location = request.object.get("location");
        var time = request.object.createdAt;
        var promise = request.object.get("promise");
        var reSaved = request.object.get("reSaved");
        var userId = request.object.get("userId");

        /*****  determine where to add this contribution  *****/
        (function(){
            if(promise == null){
                var query = new Parse.Query("FlatCluster");
                query.withinMiles("location", location, maxMilesToAdd);
                query.greaterThanOrEqualTo("validUntil", futureInfinity);
                query.greaterThanOrEqualTo("tk", new Date(time.getTime() - 1000*60*minuteCutoffAdd));
                return query.find();
            } else if(promise == "newCluster"){
                /*TODO: to cut down on the number of API calls, replace this query with a Parse.Promise.as(1) or something like that*/
                //must return an object with "then" function attached such as query.find()
                var dummyQuery = new Parse.Query("FlatCluster");
                dummyQuery.get("dummyIdThatDoesNotExist");
                return dummyQuery.find();
            } else{
                var query = new Parse.Query("FlatCluster");
                query.get(promise);
                return query.find({
                    success: function(resultingClusters){
                        if(resultingClusters[0].mergedIntoClusterId == null){
                            query.get(promise); //TODO: wasting a call...
                            return query.find();
                        } else{
                            //in case the cluster was additionally merged
                            var deeperQuery = new Parse.Query("FlatCluster");
                            return deeperQuery.get(resultingCluster[0].mergedIntoClusterId);
                        }
                    },
                    error: function(error){}
                });
            }
        })().then(function(resultingClusters){
            
            var bestCluster;
            if(promise == null){
                bestCluster = findBestClusterToAddTo({"location": location, "time": time, "userId": userId}, resultingClusters);
            } else if(promise == "newCluster"){
                bestCluster = "NONE";
            } else{
                bestCluster = resultingClusters[0];
                if(bestCluster == null){
                    bestCluster = "NONE"; //guarding against the off possibility that the assigned cluster or parent cluster doesn't exist or there's some other error along the way.
                }
            }

            if(bestCluster == "NONE"){
                var newCluster = new Parse.Object("FlatCluster");
                
                //set general parameters
                newCluster.set("k", 1);
                newCluster.set("N", estimate_N(1.0));
                newCluster.set("validUntil",futureInfinity);
                newCluster.set("importance",1.0);
                newCluster.set("contributions", new Array(request.object.id));
                newCluster.set("contributingUsers", [request.object.get("userId")]);
                newCluster.set("titlePhotoIdArray", []);
                newCluster.set("titleMessageIdArray", []);
                if(request.object.get("image") || request.object.get("type") == "photo"){ //TODO: in the future, only check the type since photo will exist on AWS
                    newCluster.set("titlePhotoId", request.object.id);
                    newCluster.add("titlePhotoIdArray", request.object.id);
                } else if(request.object.get("message") || request.object.get("type") == "message"){ //TODO: in the future, only check the type since message will exist on AWS
                    newCluster.set("titleMessageId", request.object.id);
                    newCluster.add("titleMessageIdArray", request.object.id);
                } else{
                    newCluster.set("titlePhotoId", defaultImageId);
                }
                //set space parameters
                newCluster.set("location",location);
                newCluster.set("alphan",alpha0);
                newCluster.set("betan",beta0);
                //set time parameters
                newCluster.set("t1",time);
                newCluster.set("tk",time);
                newCluster.set("tbar", time);
                newCluster.set("alpha",alpha);
                newCluster.set("beta",beta);

                var latitude = location.latitude;
                var longitude = location.longitude;
                Parse.Cloud.httpRequest({ url: 'https://maps.googleapis.com/maps/api/geocode/json?latlng=' + latitude + ',' + longitude + '&sensor=false&result_type=neighborhood|locality|country&key=AIzaSyClR6wH3_BfA1bXFjr3LEI-Cp_SiOrPJog',
                        success: function(httpResponse) {
                            var res = JSON.parse(httpResponse.text);
                            var addressParts = res.results[0].formatted_address.split(",");
                            var country = "";
                            var state = "";
                            var city = "";
                            var neighborhood = "";
                            if(addressParts.length > 0){
                                country = addressParts[addressParts.length - 1];
                            }
                            if(addressParts.length > 1){
                                state = addressParts[addressParts.length - 2];
                            }
                            if(addressParts.length > 2){
                                city = addressParts[addressParts.length - 3];
                            }
                            if(addressParts.length > 3){
                                neighborhood = addressParts[addressParts.length - 4];
                            }
                            newCluster.set("country", country);
                            newCluster.set("state", state);
                            newCluster.set("city", city);
                            newCluster.set("neighborhood", neighborhood);
                            newCluster.save();
                        },
                        error: function(httpResponse) {
                            console.error('Request failed with response code ' + httpResponse.status);
                            newCluster.save(); //save the cluster anyway
                        }
                    });
            } else{
                /*****  retrieve data from already existing cluster  *****/
                //general stuff
                var oldk = bestCluster.get("k");
                var oldN = bestCluster.get("N");
                //space stuff
                var oldLocation = bestCluster.get("location");
                var oldMeanLong = oldLocation.longitude;
                var oldMeanLat = oldLocation.latitude;
                //time stuff
                var oldtbar = bestCluster.get("tbar");
               
                /*****  retrieve the data for the contribution  *****/
                var contributionLat = location.latitude;
                var contributionLong = location.longitude;
                var newtk = request.object.createdAt;
               
                /*****  calculate stuff  *****/
                var newMeanLong = (oldk*oldMeanLong + contributionLong)/(oldk + 1);
                var newMeanLat = (oldk*oldMeanLat + contributionLat)/(oldk + 1);
                var x_dist_to_old_mean = oldLocation.milesTo(new Parse.GeoPoint({latitude: oldMeanLat, longitude: contributionLong}))
                var y_dist_to_old_mean = oldLocation.milesTo(new Parse.GeoPoint({latitude: contributionLat, longitude: oldMeanLong}))
                var x_dist_mean_moved = oldLocation.milesTo(new Parse.GeoPoint({latitude:oldMeanLat, longitude:newMeanLong}));
                var y_dist_mean_moved = oldLocation.milesTo(new Parse.GeoPoint({latitude:newMeanLat, longitude:oldMeanLong}));

                /***** modify the cluster *****/
                //general stuff
                bestCluster.increment("k",1);
                bestCluster.increment("N",estimate_N(bestCluster.get("k")) - oldN);
                if(request.object.get("image") || request.object.get("type") == "photo"){
                    bestCluster.set("titlePhotoId", request.object.id); //TODO: remove this since we're entirely moved over to array
                    bestCluster.add("titlePhotoIdArray", request.object.id);
                } else if(request.object.get("message") || request.object.get("type") == "message"){
                    // Added by cbo to handle 2 messages
                    bestCluster.set("titleMessageId2", bestCluster.get("titleMessageId")); //TODO: remove this since we're entirely moved over to array
                    bestCluster.set("titleMessageId", request.object.id); //TODO: remove this since we're entirely moved over to array
                    bestCluster.add("titleMessageIdArray", request.object.id);
                } else{/*Do nothing*/}
                bestCluster.add("contributions", request.object.id);
                //Here we log the contributing users and also protect ourselves from artificial inflation of importance.
                var amountToIncrementImportanceBy = 1.0;
                var contributingUsers = bestCluster.get("contributingUsers");
                var currentUserId = request.object.get("userId");
                bestCluster.add("contributingUsers", currentUserId);
                if(contributingUsers.length < maxUserCountToIterate){
                    for(var i = 0; i < contributingUsers.length; i++){
                        if(contributingUsers[i] == currentUserId && powerUsers.indexOf(currentUserId) == -1){ //allow power users to inflate the importance
                            amountToIncrementImportanceBy /= 2.0; //the importance added by a user goes along the sequense 1, 1/2, 1/4, 1/8, ... As a result, any given user can at most increment by 2.
                        }
                    }
                }
                bestCluster.increment("importance", amountToIncrementImportanceBy);
                //space stuff
                bestCluster.increment("alphan",1.0); //one for each coordinate
                bestCluster.increment("betan",0.5*Math.pow(x_dist_to_old_mean,2) + 0.5*Math.pow(y_dist_to_old_mean,2) + x_dist_mean_moved*x_dist_to_old_mean + y_dist_mean_moved*y_dist_to_old_mean + 0.5*(oldk+1)*Math.pow(x_dist_mean_moved,2) + 0.5*(oldk+1)*Math.pow(y_dist_mean_moved,2)); //one for each coordinate
                bestCluster.set("location", new Parse.GeoPoint({latitude: newMeanLat, longitude: newMeanLong}));
                //time stuff
                bestCluster.set("tk",newtk);
                bestCluster.set("tbar",new Date(oldtbar.getTime()*oldk/(oldk+1.0) + newtk/(oldk+1.0)));

                bestCluster.save({
                    success: function(updatedCluster){
                        //push notifications count as one API request, but at least it's one per contribution, not one per contribution per user which is what getContributionIdsInCluster costs.
                        //only send push if promise == nil since otherwise it's already been sent on client side
                        var bufferTime = 7000;
                        if(request.object.get("type") == "message"){
                            bufferTime = 1000;
                            console.log("was a message");
                        } else{
                            console.log("was an image");
                        }
                        bufferTime = 0; //TODO: get rid of this. I just added it back since we are temporarily uploading the content to parse.
                        if(!promise){
                            console.log("pushing in "+bufferTime + " milli seconds");
                            Parse.Push.send({
                                channels: [ "event" + bestCluster.id ],
                                expiration_interval: 5, //expires in 5 seconds in case a user has their phone turned off etc. Remember that the contributions will still be gotten via a pull etc anyway.
                                push_time: new Date((new Date()).getTime() + bufferTime), //this is meant to ensure that the content is available on AWS by the time we look for it. TODO: find a better way.
                                data: {
                                    "alert": "New stuff at your event!",
                                    "c": request.object.id,
                                    "t": request.object.get("type"),
                                    "u": request.object.get("userId"),//TODO: also send along time of creation to allow sorting on the client side. Maybe replace this with a relevance value that would just correspond to time at first but might ultimately be something more sophisticated
                                    "sound": "cheering.caf",
                                    "m": request.object.get("message")
                                }
                            }, {success: function() {},error: function(error) {}});
                        }
                    
                        //TODO: maybe don't do this every time to avoid wasting api calls
                        var queryMerge = new Parse.Query("FlatCluster");
                        queryMerge.withinMiles("location", updatedCluster.get("location"), maxMilesToMerge);
                        queryMerge.greaterThanOrEqualTo("validUntil", futureInfinity);
                        queryMerge.greaterThanOrEqualTo("tk", new Date(updatedCluster.get("tk").getTime() - 1000*60*minuteCutoffMerge));
                        queryMerge.find({
                            success: function(nearbyActiveClusters){
                                var neighborCluster = findBestClusterToMergeWith(updatedCluster, nearbyActiveClusters);
                                if(neighborCluster != "NONE"){
                                    neighborCluster.set("validUntil", new Date()); //invalidate the neighboring cluster
                                    neighborCluster.set("mergedIntoClusterId",updatedCluster.id);
                                    neighborCluster.save({
                                        success: function(invalidatedNeighbor){
                                            /*****  get necessary data from the invalidated neighbor  *****/
                                            //general stuff
                                            var invalidatedNeighbork        = invalidatedNeighbor.get("k");
                                            //space stuff
                                            var invalidatedNeighborLocation = invalidatedNeighbor.get("location");
                                            var invalidatedNeighborLat      = invalidatedNeighborLocation.latitude;
                                            var invalidatedNeighborLong     = invalidatedNeighborLocation.longitude;
                                            //time stuff
                                            var invalidatedNeighbort1   = invalidatedNeighbor.get("t1");
                                            var invalidatedNeighbortk   = invalidatedNeighbor.get("tk");
                                            var invalidatedNeighbortbar = invalidatedNeighbor.get("tbar");

                                            /*****  get necessary data from the updated cluster  *****/
                                            //general stuff
                                            var updatedClusterk        = updatedCluster.get("k");
                                            //space stuff
                                            var updatedClusterLocation = updatedCluster.get("location");
                                            var updatedClusterLat      = updatedClusterLocation.latitude;
                                            var updatedClusterLong     = updatedClusterLocation.longitude;
                                            //time stuff
                                            var updatedClustert1   = updatedCluster.get("t1");
                                            var updatedClustertk   = updatedCluster.get("tk");
                                            var updatedClustertbar = updatedCluster.get("tbar");
                                            
                                            /*****  calculate the data for the merged cluster  *****/
                                            //space stuff
                                            var mergedMeanLat  = (invalidatedNeighborLat  * invalidatedNeighbork + updatedClusterLat  * updatedClusterk)/(invalidatedNeighbork + updatedClusterk);
                                            var mergedMeanLong = (invalidatedNeighborLong * invalidatedNeighbork + updatedClusterLong * updatedClusterk)/(invalidatedNeighbork + updatedClusterk);
                                            var mergedLocation = new Parse.GeoPoint({latitude: mergedMeanLat, longitude: mergedMeanLong});
                                            //time stuff
                                            var mergedt1   = new Date(Math.min(invalidatedNeighbort1.getTime(), updatedClustert1.getTime()));
                                            var mergedtk   = new Date(Math.max(invalidatedNeighbort1.getTime(), updatedClustert1.getTime()));
                                            var mergedtbar = new Date((invalidatedNeighbork*invalidatedNeighbortbar.getTime() + updatedClusterk*updatedClustertbar.getTime()) / (invalidatedNeighbork + updatedClusterk));

                                            /*****  update the parameters  *****/
                                            //general stuff
                                            updatedCluster.increment("k", invalidatedNeighbork);
                                            updatedCluster.increment("N", estimate_N(updatedClusterk + invalidatedNeighbork) - updatedCluster.get("N"));
                                            //space stuff
                                            updatedCluster.increment("alphan", invalidatedNeighbork);
                                            updatedCluster.increment("betan", invalidatedNeighbor.get("betan") - beta0 + 0.5*(invalidatedNeighbork*Math.pow(mergedLocation.milesTo(invalidatedNeighborLocation),2) + updatedClusterk*Math.pow(mergedLocation.milesTo(updatedClusterLocation),2)));
                                            updatedCluster.set("location", mergedLocation);
                                            //time stuff
                                            updatedCluster.set("t1", mergedt1);
                                            updatedCluster.set("tk",mergedtk);
                                            updatedCluster.set("tbar",mergedtbar);
                                        


                                            var updatedClusterImportance = updatedCluster.get("importance");
                                            var invalidatedNeighborImportance = invalidatedNeighbor.get("importance");
                                            var invalidatedNeighborContributionIds = invalidatedNeighbor.get("contributions");
                                            var invalidatedNeighborContributingUsers = invalidatedNeighbor.get("contributingUsers");
                                            
                                            for(var i = 0; i < invalidatedNeighborContributionIds.length; i++){
                                                //TODO: technically if two different clusters simultaneously try to merge with a given cluster, they will both duplicate its images.
                                                //Then, if those two clusters end up merging in the future, duplicated will exist. As a result, I here use addUnique to prevent this.
                                                //However, a subtlety in this approach is that the importance of the overlapping images gets double counted. I will accept this rare
                                                //issue for now, but this is something that must be addressed in the future.
                                                updatedCluster.addUnique("contributions", invalidatedNeighborContributionIds[i]);
                                            }
                                            for(var i = 0; i < invalidatedNeighborContributingUsers.length; i++){
                                                updatedCluster.add("contributingUsers",invalidatedNeighborContributingUsers[i]);
                                            }
                                            updatedCluster.increment("importance", invalidatedNeighbor.get("importance"));
                                            updatedCluster.save();
                                            
                                            //send push notification to the involved subscribers
                                            Parse.Push.send({
                                                channels: [ "event"+updatedCluster.id, "event"+invalidatedNeighbor.id],
                                                data: {
                                                    alert: "Your event merged with another event.",
                                                    o:invalidatedNeighbor.id,
                                                    n:updatedCluster.id
                                                }
                                            }, {success: function(){}, error: function(error){}});
                                            
                                            /*this next part looks for clusters that were themselves merged into the neighbor cluster and updates their mergedIntoClusterId. This may not really
                                            be necessary since presumably clusters only merge once in a while and the chance of this happening multiple times is slim to none. Either way, it's included for
                                            completeness.*/
                                            var queryUpdateMergedIntoClusterId = new Parse.Query("FlatCluster");
                                            queryUpdateMergedIntoClusterId.equalTo("mergedIntoClusterId", neighborCluster.id);
                                            queryUpdateMergedIntoClusterId.find({
                                                success:function(results){
                                                    for(var i = 0; i < results.length; i++){
                                                        results[i].set("mergedIntoClusterId", updatedCluster.id);
                                                        results[i].save();
                                                    }
                                                }
                                            });
                                        }
                                    });
                                }
                            },
                            error: function(error){response.error(error);}
                        });
                    }
                });
            }
        });
    } //end check if reSaved == 1. In other words, if reSaved == 1, nothing happens in here...
});


///////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////// ADDITION TO ALREADY EXISTING CLUSTER  //////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////


function calculateAddFitValue(cluster, contributionData){
    /*****  retrieve the data for the new object  *****/
    var objectLocation = contributionData["location"];
    var objectTime = contributionData["time"];
    var userId = contributionData["userId"];

    /*****  retrieve the data for this cluster  *****/
    //general stuff
    var k = cluster.get("k");
    var N = cluster.get("N");
    //space stuff
    var alphan = cluster.get("alphan");
    var betan  = cluster.get("betan");
    //time stuff - note, all time variables are in units of seconds!
    var alpha  = cluster.get("alpha");
    var beta   = cluster.get("beta");
    var t1     = cluster.get("t1").getTime()/1000.0;
    var tk     = cluster.get("tk").getTime()/1000.0;
    var tbar   = cluster.get("tbar").getTime()/1000.0;
    var tnew   = objectTime.getTime()/1000.0;

    /*****  compute the relevant parameters  *****/
    var sigma = Math.pow((2*k+1)/(2*k)*betan/alphan,0.5);

    /*****  relative data between the two clusters  *****/
    var clusterDistance = cluster.get("location").milesTo(objectLocation);

    /*****  compute the probabilities and fit value  *****/
    var spatial_probability = Math.exp(-Math.pow(clusterDistance/sigma,2)/2.0); //TODO: switch this to the t-distribution instead
    var temporal_probability;
    //intended to also support retroactive clustering (e.g. for merges)
    if(objectTime >= tk){
        temporal_probability = Math.pow((2*(N-k)*(tk-t1) + k*(tbar-t1) + beta)/((N-k)*(tk+tnew-2*t1) + k*(tbar-t1) + beta), k + alpha + 1);
    } else if(objectTime <= t1){
        temporal_probability = 0; //not necessarily correct...
    } else{
        temporal_probability = 1;
    }
    var userProbabilityBoost = 1;
    var contributingUsers = cluster.get("contributingUsers");
    if(userId != "null"){
        for(var i = 0; i < contributingUsers.length; i++){
            if(contributingUsers[i] == userId){
                userProbabilityBoost += 1; //TODO: up for debate
            }
        }
    }
    var fitValue = spatial_probability * temporal_probability * userProbabilityBoost;
    return fitValue;
}

function wasClusterActiveAt(cluster, time){
    //we define an active cluster as one where a contribution right at the center of it would be clustered with the cluster
    var fitAddValueAtCenter = calculateAddFitValue(cluster, {"location": cluster.get("location"), "time": time, "userId": "null"});
    if(fitAddValueAtCenter > thresholdToAdd){
        return "YES";
    } else{
        return "NO";
    }
}

/*
This is where the logic necessary to determine where to add a photo is placed
*/
function findBestClusterToAddTo(newObjectData, nearbyActiveClusters){
    /*****  retrieve the data for the new object  *****/
    var objectLocation = newObjectData["location"];
    var objectTime = newObjectData["time"];
    var userId = newObjectData["userId"];
    var bestCluster = "NONE";
    var bestFitValue = -1000000; //start with very bad fit value
    var secondBestFitValue = bestFitValue - 1;

    //for now just return the nearest cluster as long as it's within 0.1 miles
    for(var i = 0; i < nearbyActiveClusters.length; i++){
        var cluster = nearbyActiveClusters[i];
        var fitValue = calculateAddFitValue(cluster, {"location": objectLocation, "time": objectTime, "userId": userId});

        if(fitValue > thresholdToAdd && fitValue > bestFitValue){
            secondBestFitValue = bestFitValue;
            bestFitValue = fitValue;
            bestCluster = nearbyActiveClusters[i];
        } else if(fitValue > secondBestFitValue){
            secondBestFitValue = fitValue;
        }
    }
//    if(bestFitValue < secondBestFitValue*multiplier){
//        bestCluster = "NONE";
//    }
    return bestCluster;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// MERGING TWO CLUSTERS  //////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

function findBestClusterToMergeWith(baseCluster, nearbyActiveClusters){
    /***** retrieve the data *****/
    var baset1 = baseCluster.get("t1");
    var baseLocation = baseCluster.get("location");
    
    var bestCluster = "NONE";
    var bestMergeFitValue = 0;
    for(var i = 0; i < nearbyActiveClusters.length; i++){
        var cluster = nearbyActiveClusters[i];
        if(cluster.id != baseCluster.id){
            var mergeFitValue;
            if(baset1 < cluster.get("t1")){
                mergeFitValue = calculateAddFitValue(baseCluster, {"location":cluster.get("location"), "time":cluster.get("t1"), "userId": "null"});
            } else{
                mergeFitValue = calculateAddFitValue(cluster, {"location":baseCluster.get("location"), "time":baseCluster.get("t1"), "userId": "null"});
            }
            if(mergeFitValue > thresholdToMerge && mergeFitValue > bestMergeFitValue){
                bestCluster = cluster;
                bestMergeFitValue = mergeFitValue;
            }
        }
    }
    return bestCluster;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////       MODIFY OBJECTS       ///////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

Parse.Cloud.define("incrementImportance",function(request, response){
    //TODO: check somehow for userId to see if this user has icremented the importance already.
    var clusterId = request.object.clusterId;
    var extraImportance = request.object.extraImportance;
    var userId = request.object.userId;
    var query = new Parse.Query("FlatCluster");
    //using pointers to avoid first having to retrieve the object just to update it
    var FlatCluster = Parse.Object.extend("FlatCluster");
    var clusterObject = new FlatCluster;
    clusterObject.id = clusterId;
    clusterObject.increment("importance", extraImportance);
    clusterObject.add("contributingUsers", userId);
    clusterObject.save();

//    var clusterId = request.object.clusterId;
//    var extraImportance = request.object.extraImportance;
//    var userId = request.object.userId;
//    var query = new Parse.Query("FlatCluster");
//    query.get(clusterId);
//    query.find({
//        success: function(results){
//            var cluster = results[0];
//            cluster.increment("importance", extraImportance);
//            cluster.addUnique("contributers", userId);
//            cluster.save();
//        }
//    })
    
})

///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////      RETRIEVAL METHODS     ///////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////


Parse.Cloud.define("getClusters", function(request, response) {
    var inputTime = new Date(); //TODO: this should really come from the request to support historic look back
    var location = new Parse.GeoPoint({latitude: request.params.latitude, longitude: request.params.longitude});
    var userId = request.params.userId; //TODO: must include this in the call to getClusters!

    var localQuery = new Parse.Query("FlatCluster");
    localQuery.withinMiles("location", location, localGettingMilesCutoff);
    localQuery.greaterThanOrEqualTo("validUntil", futureInfinity);
    localQuery.greaterThanOrEqualTo("tk", new Date(inputTime.getTime() - 1000*60*minuteCutoffGetLocal));
    
    var localQueryWrapped = new Parse.Query("FlatCluster");
    localQueryWrapped.matchesKeyInQuery("objectId", "objectId", localQuery);

    var globalQuery = new Parse.Query("FlatCluster");
    globalQuery.greaterThanOrEqualTo("validUntil", futureInfinity);
    globalQuery.greaterThanOrEqualTo("tk", new Date(inputTime.getTime() - 1000*60*minuteCutoffGetGlobal));
    globalQuery.greaterThanOrEqualTo("importance", globalImportanceThreshold);

    var totalQuery = Parse.Query.or(localQueryWrapped, globalQuery);
    totalQuery.find({
        success: function(clusterObjects){
            response.success({"customClusterObjects": filterAndOrderClusters({"location": location, "time": inputTime, "userId": userId}, clusterObjects)});
        }, error: function(error){response.error(error);}
    });
});

/*This function attempts to filter and order all clusters simultaneously to reduce the number of API calls (this way we don't have to have two different queries local/global)*/
function filterAndOrderClusters(baseData, clusters){
    var baseLocation = baseData["location"];
    var baseTime = baseData["time"];
    var userId = baseData["userId"];
    
    var fitAndObjectList = [];
    var indexOfBestAdd = -1;
    var bestAddFitValue = 0;
    for(var i = 0; i < clusters.length; i++){
        var cluster = clusters[i];
        var importance = cluster.get("importance");
        var distanceToCluster = cluster.get("location").milesTo(baseLocation);
        
        var clusterTime = cluster.get("tk");
        var deltaTime = (baseTime.getTime() - clusterTime.getTime())/1000.0; //seconds between now and last update to cluster
        
        var localFitValue = (importance / ((0.001 + distanceToCluster)/(typicalDistanceForGettingLocal))) * Math.exp(-deltaTime/secondDecayForLocalGetting);
        var globalFitValue = importance*Math.exp(-deltaTime/secondDecayForGlobalGetting); //base global fit value only on importance and time
        console.log("--------------------");
        console.log(cluster.id);
        console.log(localFitValue);
        if(localFitValue > minLocalFitValue || globalFitValue > minGlobalFitValue){

            var titlePhotoIdArray = cluster.get("titlePhotoIdArray");
            var titlePhotoId = titlePhotoIdArray[titlePhotoIdArray.length - 1];

            var titleMessageIdArray = cluster.get("titleMessageIdArray");
            var titleMessageId = titleMessageIdArray[titleMessageIdArray.length - 1];
            var titleMessageId2 = titleMessageIdArray[titleMessageIdArray.length - 2];
            
            var titlePhotoIdDict = {};
            var titleMessageIdDict = {};
            var titleMessageId2Dict = {};
            titlePhotoIdDict[titlePhotoId] = "photo"
            titleMessageIdDict[titleMessageId] = "message"
            titleMessageId2Dict[titleMessageId2] = "message"
            var titleContributionArray = []
            if(titlePhotoId){
                titleContributionArray.push(titlePhotoIdDict);
            }
            if(titleMessageId){
                titleContributionArray.push(titleMessageIdDict);
            }
            if(titleMessageId2){
                titleContributionArray.push(titleMessageId2Dict);
            }

            var newCustomClusterObject = {};
            newCustomClusterObject["objectId"] = cluster.id;
//            newCustomClusterObject["titleContributionIds"] = titleContributionArray;
            newCustomClusterObject["titlePhotoId"] = titlePhotoId;
            newCustomClusterObject["importance"] = Math.floor(importance);
            newCustomClusterObject["latitude"] = cluster.get("location").latitude;
            newCustomClusterObject["longitude"] = cluster.get("location").longitude;
            newCustomClusterObject["updatedAt"] = cluster.updatedAt;
            newCustomClusterObject["country"] = cluster.get("country");
            newCustomClusterObject["city"] = cluster.get("city");
            newCustomClusterObject["state"] = cluster.get("state");
            newCustomClusterObject["neighborhood"] = cluster.get("neighborhood");
            newCustomClusterObject["containsUser"] = "NO"; //only at most one gets "YES" here, so we default to "NO" and then update it to YES for a possible best cluster
            newCustomClusterObject["isActive"] = wasClusterActiveAt(cluster, new Date());

            if(localFitValue > minLocalFitValue){
                var addFitValue = 0; //default to 0 so that if really old or far away, it will not be clustered
                if(deltaTime/60.0 < minuteCutoffAdd && distanceToCluster < maxMilesToAdd){
                    addFitValue = calculateAddFitValue(cluster, {"location": baseLocation, "time": baseTime, "userId": userId});
                }
                if(addFitValue > thresholdToAdd && addFitValue > bestAddFitValue){
                    indexOfBestAdd = fitAndObjectList.length;
                    bestAddFitValue = addFitValue;
                }
                fitAndObjectList.push([localFitValue, newCustomClusterObject]);
            } else{
                fitAndObjectList.push([globalFitValue, newCustomClusterObject]);
            }
        }
        if(indexOfBestAdd >= 0){
            fitAndObjectList[indexOfBestAdd][1]["containsUser"] = "YES";
        }
    }
    //sort by fit value, largest first
    fitAndObjectList.sort(mySortFunction);
    var returnObjects = new Array();
    var fitValues = "";
    for(var i = 0; i < fitAndObjectList.length; i++){
        returnObjects.push(fitAndObjectList[i][1]);
    }
    return returnObjects;
}

/*this is a comparator function for two arrays. Here, we compare by the first element in the array with the larger value ranking ahead of the smaller value. This is technically where a lot of the magic lies since it will determine the order of the clusters*/
function mySortFunction(arrayA,arrayB){
    //one that you're apart of always trumps any other event and will always be on top. Otherwise, the one with the best fit value wins
    if(arrayA[1]["containsUser"] == "YES"){
        return -1;
    } else if(arrayB[1]["containsUser"] == "YES"){
        return 1;
    } else if(arrayA[0] < arrayB[0]){
        return 1;
    } else{
        return -1;
    }
}

function shouldBeCensored(flaggedBy){
    if(flaggedBy.length > 1 || flaggedBy.indexOf("admin") != -1){
        return "YES";
    }
    return "NO";
}

/*This method returns the photo ids in the given cluster.*/
Parse.Cloud.define("getContributionIdsInCluster", function(request, response){
    var clusterId = request.params.clusterId;
    var query = new Parse.Query("FlatCluster");
    query.get(clusterId);
    query.find({
        success: function(results){
            if(results.length > 0){
                var mergedIntoClusterId = results[0].get("mergedIntoClusterId");
                if(!mergedIntoClusterId){
                    var contributionIds = results[0].get("contributions");
                    var contributionQuery = new Parse.Query("Contribution");
                    contributionQuery.containedIn("objectId", contributionIds);
                    contributionQuery.addDescending("createdAt");
                    contributionQuery.find({
                        success: function(results){
                            sortedContributionIds = new Array();
                            for(var i = 0; i < results.length; i++){
                                var flaggedBy = results[i].get("flaggedBy");
                                if(shouldBeCensored(flaggedBy) == "YES"){
                                    continue;
                                }
                                var contributionDict = {};
                                contributionDict[results[i].id] = "photo";
                                if(results[i].get("image") || results[i].get("type") == "photo"){
                                    contributionDict[results[i].id] = "photo";
                                    contributionDict["type"] = "photo";
                                    contributionDict["message"] = "";
                                } else if(results[i].get("message") || results[i].get("type") == "message"){
                                    contributionDict[results[i].id] = "message";
                                    contributionDict["type"] = "message";
                                    contributionDict["message"] = results[i].get("message");
                                } else{
                                    contributionDict[results[i].id] = "other";
                                    contributionDict["type"] = "other";
                                }
                                contributionDict["userId"] = results[i].get("userId");
                                contributionDict["contributionId"] = results[i].id;
                                contributionDict["createdAt"] = results[i].createdAt;
                                sortedContributionIds.push(contributionDict);
                            }
                            response.success({"contributionIds": sortedContributionIds});
                        }
                    });
                } else{
               
//                    response.success({"contributionIds":new Array({"mergedIntoId": mergedIntoClusterId})});
               
               
                    //this means that this cluster was later merged into another cluster. mergedIntoClusterId keeps track of the last of these merges so that no recursive issues need to be taken care of.
                    var mergedQuery = new Parse.Query("FlatCluster");
                    mergedQuery.get(mergedIntoClusterId);
                    mergedQuery.find({
                        success: function(results){
                            var contributionIds = results[0].get("contributions");
                            var contributionQuery = new Parse.Query("Contribution");
                            contributionQuery.containedIn("objectId", contributionIds);
                            contributionQuery.addDescending("createdAt");
                            contributionQuery.find({
                                success: function(results){
                                    sortedContributionIds = new Array();
                                    for(var i = 0; i < results.length; i++){
                                        var contributionDict = {};
                                        contributionDict[results[i].id] = "photo";
                                        if(results[i].get("image") || results[i].get("type") == "photo"){
                                            contributionDict[results[i].id] = "photo";
                                        } else if(results[i].get("message") || results[i].get("type") == "message"){
                                            contributionDict[results[i].id] = "message";
                                        } else{
                                            contributionDict[results[i].id] = "other";
                                        }
                                        sortedContributionIds.push(contributionDict);
                                    }
                                    response.success({"contributionIds": sortedContributionIds});
                                }
                            });
                        },
                        error: function(error){
                            response.error(error);
                        }
                    });
               
               
                }
            } else{
                response.success({"contributionIds": []});
            }
        }, error: function(error){
            response.error(error);
        }
    });
})

//This method returns the userIds for a particular cluster in the order that they contributed. This is used on the client side for generating the avatars
Parse.Cloud.define("getStatusInCluster", function(request, response){
    var clusterId = request.params.clusterId;
    var query = new Parse.Query("FlatCluster");
    query.get(clusterId);
    query.find({
        success: function(cluster){
            var contributingUsers = cluster[0].get("contributingUsers");
            var statusArray = new Array();
            for(var i = 0; i < contributingUsers.length; i++){
                var userId = contributingUsers[i];
                if(statusArray.indexOf(userId) == -1){
                    statusArray.push(userId);
                }
            }
            response.success({"statusArray":statusArray});
        },
        error: function(error){
            response.error(error);
        }
    })
})

//This method returns the clusterId of a possibly parent cluster to a given clusterId. If no such parent cluster exists, it just returns the original clusterId
Parse.Cloud.define("getParentClusterId", function(request, response){
    var clusterId = request.params.clusterId;
    var query = new Parse.Query("FlatCluster");
    query.get(clusterId);
    query.find({
        success: function(cluster){
            //TODO: should this be cluster[0].get()?
            var mergedIntoClusterId = cluster.get("mergedIntoClusterId");
            if(mergedIntoClusterId == null){
                response.success({"clusterId": clusterId});
            } else{
                response.success({"clusterId": mergedIntoClusterId});
            }
        }
    });
})

Parse.Cloud.define("flagContribution", function(request, response){
    var contributionId = request.params.contributionId;
    var clusterId = request.params.clusterId;
    var userId = request.params.userId;

    var contributionSaveDone = false;
    var clusterSaveDone = false;

    //TODO: use pointers here to cut down one API call.
    var contributionQuery = new Parse.Query("Contribution");
    contributionQuery.get(contributionId);
    contributionQuery.find({
        success: function(resultingContribution){
            contributionSaveDone = true;
            if(resultingContribution.length > 0){
                var contribution = resultingContribution[0];
                var flaggedBy = contribution.get("flaggedBy");
                if(flaggedBy.indexOf(userId) == -1){ //only allow each user to flag a piece of content once
                    contribution.add("flaggedBy", userId);
                    contribution.increment("reviewCount", 1);
                }
                contribution.set("reSaved", 1);
                contribution.save();
            }
            if(contributionSaveDone && clusterSaveDone){
                response.success();
            }
        },
        error: function(error){
            response.error(error);
        }
    });
    if(clusterId != "none"){
        var clusterQuery = new Parse.Query("FlatCluster");
        clusterQuery.get(clusterId);
        clusterQuery.find({
            success: function(resultingCluster){
                clusterSaveDone = true;
                if(resultingCluster.length > 0){
                    var cluster = resultingCluster[0];
                    var titlePhotoIdArray = cluster.get("titlePhotoIdArray");
                    var titleMessageIdArray = cluster.get("titleMessageId");
                    //go through each array and delete the given contributionId
                    var indexOfContributionInTitlePhotoIdArray = titlePhotoIdArray.indexOf(contributionId);
                    var indexOfContributionInTitleMessageIdArray = titleMessageIdArray.indexOf(contributionId);
                    if(indexOfContributionInTitlePhotoIdArray != -1){
                        console.log("1 - array"+titlePhotoIdArray);
                        titlePhotoIdArray.splice(indexOfContributionInTitlePhotoIdArray, 1);
                        console.log("2 - array"+titlePhotoIdArray);
                        cluster.set("titlePhotoIdArray",titlePhotoIdArray);
                    } else if(indexOfContributionInTitleMessageIdArray != -1){
  //                      titleMessageIdArray.splice(indexOfContributionInTitleMessageIdArray, 1);
                    }
                    cluster.save();
                }
                if(contributionSaveDone && clusterSaveDone){
                    response.success();
                }
            },
            error: function(error){
                response.error(error);
            }
        });
    } else{
        clusterSaveDone = true;
        if(contributionSaveDone && clusterSaveDone){
            response.success();
        }
    }
})


///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////     HELPER METHODS     /////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

/*This method returns a dictionary of location data: country, state, city, etc.*/
//TODO: move to iOS side
Parse.Cloud.define("getLocationData", function(request, response) {
    var latitude = request.params.latitude;
    var longitude = request.params.longitude;
    Parse.Cloud.httpRequest({ url: 'https://maps.googleapis.com/maps/api/geocode/json?latlng=' + latitude + ',' + longitude + '&sensor=false&result_type=neighborhood|locality|country&key=AIzaSyClR6wH3_BfA1bXFjr3LEI-Cp_SiOrPJog',
        success: function(httpResponse) {
            var res = JSON.parse(httpResponse.text);
            var addressParts = res.results[0].formatted_address.split(",");
            var country = "";
            var state = "";
            var city = "";
            var neighborhood = "";
            if(addressParts.length > 0){
                country = addressParts[addressParts.length - 1];
            }
            if(addressParts.length > 1){
                state = addressParts[addressParts.length - 2];
            }
            if(addressParts.length > 2){
                city = addressParts[addressParts.length - 3];
            }
            if(addressParts.length > 3){
                neighborhood = addressParts[addressParts.length - 4];
            }
            response.success({"country" : country, "state" : state, "city" : city, "neighborhood" : neighborhood});
        },
        error: function(httpResponse) {
            console.error('Request failed with response code ' + httpResponse.status);
        }
    });
});

/*This method estimates the total number of contributions in a cluster given that k have already occurred*/
function estimate_N(k){
    return k + Math.ceil(Math.pow(k,0.5));
}





