package com.longweekendmobile.android.xflash;

//  PracticeFragment.java
//  Xflash
//
//  Created by Todd Presson on 1/26/2012.
//  Copyright 2012 Long Weekend LLC. All rights reserved.
//
//  public View onCreateView(LayoutInflater  ,ViewGroup  ,Bundle  )     @over
//  public void onDestroyView()                                         @over
//  public void onCreateOptionsMenu(Menu  ,MenuInflater  )              @over
//  public void onPrepareOptionsMenu(Menu  )                            @over
//  public boolean onOptionsItemSelected(MenuItem  )                    @over
//
//  public static void setPracticeBlank()
//  public static void setRight()
//  public static void setWrong()
//  public static void setGoAway()
//  public static void reveal()
//  public static void practiceClick(View  )
//  public static void browseClick(View  )
//  public static void goRight()
//
//  public static void dumpObservers()
//
//  private static void launchBrowseCard(int  )
//
//  private void loadSavedPracticeValues()
//  private void toggleCardStarred()
//  private void launchAddCard()
//  private void fixCardEmail()
//  private void setupObservers()
//  private void updateFromSubscriptionObserver(Object  )
//  private void updateFromActiveTagObserver()

import java.util.Observable;
import java.util.Observer;

import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Resources;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;

import com.longweekendmobile.android.xflash.model.JapaneseCard;
import com.longweekendmobile.android.xflash.model.Tag;
import com.longweekendmobile.android.xflash.model.TagPeer;
import com.longweekendmobile.android.xflash.model.UserHistoryPeer;

public class PracticeFragment extends Fragment
{
    private static final String MYTAG = "XFlash PracticeFragment";
    
    public static final int STUDYING_INDEX = 0;
    public static final int RIGHT1_INDEX = 1;
    public static final int RIGHT2_INDEX = 2;
    public static final int RIGHT3_INDEX = 3;
    public static final int LEARNED_INDEX = 4;
    
    private static Observer activeTagObserver = null;
    private static Observer onStopObserver = null;
    private static Observer subscriptionObserver = null;
    
    // made public for access in PracticeScreen
    public static int rightStreak = 0;
    public static int wrongStreak = 0;
    public static int numRight = 0;
    public static int numWrong = 0;
    public static int numViewed = 0;
    
    public static int practiceViewStatus = -1;

    private static RelativeLayout practiceLayout;

    private static Tag currentTag = null;
    private static JapaneseCard currentCard = null;

    private static boolean needToReloadCard = false;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState)
    {
        // allow this fragment to open the options menu via hardware button
        setHasOptionsMenu(true);

        setupObservers();
       
        // inflate the layout for our practice activity
        practiceLayout = (RelativeLayout)inflater.inflate(R.layout.practice, container, false);

        // if there is no tag loaded, default to Long Weekend Favorites
        currentTag = XflashSettings.getActiveTag();           
        currentCard = (JapaneseCard)XflashSettings.getActiveCard();
        
        // set up view based on current study mode
        if( XflashSettings.getStudyMode() == XflashSettings.LWE_STUDYMODE_PRACTICE )    
        {
            // if we're not revealed, reset to blank (in case of mode change)
            if( practiceViewStatus != PracticeScreen.PRACTICE_VIEW_REVEAL )
            {
                practiceViewStatus = PracticeScreen.PRACTICE_VIEW_BLANK;
            }
        }
        else  
        {
            practiceViewStatus = PracticeScreen.PRACTICE_VIEW_BROWSE;
        } 
    
        // load all view elements and set up based on view status
        loadSavedPracticeValues();
        PracticeScreen.initialize(practiceLayout,currentTag,currentCard);
        PracticeScreen.setupPracticeView(practiceViewStatus);

        if( currentTag.needShowAllLearned() )
        {
            XflashAlert.fireTagLearned(currentTag);
        }

        return practiceLayout;

    }  // end onCreateView()


    @Override
    public void onDestroyView()
    {
        super.onDestroyView();

        // free static layout resources
        practiceLayout = null;
        PracticeScreen.dump();

    }  // end onDestroyView()


    @Override
    public void onCreateOptionsMenu(Menu menu,MenuInflater inflater) 
    {
        // inflate our options menu from xml
        inflater.inflate(R.menu.practice_options, menu);
    }


    @Override
    public void onPrepareOptionsMenu(Menu menu)
    {
        // set the starred menu item based on current card status
        MenuItem starredItem = (MenuItem)menu.findItem(R.id.pm_toggle_starred);
        Tag starredTag = TagPeer.starredWordsTag();

        if( TagPeer.cardIsMemberOfTag(currentCard,starredTag) )
        {
            starredItem.setTitle(R.string.pm_starred_yes);
        }
        else
        {
            starredItem.setTitle(R.string.pm_starred_no);
        }
    
    }  // end onPrepareOptionsMenu()
  

    @Override
    public boolean onOptionsItemSelected(MenuItem item) 
    {
        switch( item.getItemId() ) 
        {
            case R.id.pm_toggle_starred:    toggleCardStarred();
                                            return true;
            case R.id.pm_add_tag:           launchAddCard();
                                            return true;
            case R.id.pm_tweet:             tweetCard();
                                            return true;
            case R.id.pm_fix:               fixCardEmail();
                                            return true;

        }  // end switch
        
        // if the item clicked does not match our items, pass it up
        return( super.onOptionsItemSelected(item) );

    }  // end onOptionsItemSelected()


    @Override
    public void onResume()
    {
        super.onResume();

        if( needToReloadCard )
        {
            // IF the currently active card was removed from the currently
            // active set in a modal AddCardActivity -> AddCardToTagFragment
            // THEN we need to reload the card page after the fragment
            // resumes
            needToReloadCard = false;

            // exact same code as can be found in updateFromSubscritpionObserver
            practiceViewStatus = PracticeScreen.PRACTICE_VIEW_BLANK;
            XflashScreen.setPracticeOverride();
            Xflash.getActivity().onScreenTransition("practice",XflashScreen.DIRECTION_OPEN);
        }
    }


    // called by ExampleSentenceFragment to reset the view
    public static void setPracticeBlank()
    {
        practiceViewStatus = PracticeScreen.PRACTICE_VIEW_BLANK;
    }


    // methods for PracticeFragment and ExampleSentence to respond
    // to user right / wrong/ goaway choices
    public static void setRight()
    {
        ++numRight;
        ++numViewed;
        ++rightStreak;
        wrongStreak = 0;
        UserHistoryPeer.recordCorrectForCard(currentCard,currentTag);

    }  // end setRight()

    public static void setWrong()
    {
        ++numWrong;
        ++numViewed;
        ++wrongStreak;
        rightStreak = 0;
        UserHistoryPeer.recordWrongForCard(currentCard,currentTag);
        
        // reset our all-learned flag
        currentTag.resetAllLearned();

    }  // end setWrong()

    public static void setGoAway()
    {
        ++numRight;
        ++numViewed;
        ++rightStreak;
        wrongStreak = 0;
        UserHistoryPeer.buryCard(currentCard,currentTag);

    }  // end setGoAway()


    // called by Xflash when someone clicks 'tap for answer'
    public static void reveal()
    {
        PracticeScreen.setupPracticeView(PracticeScreen.PRACTICE_VIEW_REVEAL);
    }

    
    // method called when any button in the options block is clicked
    public static void practiceClick(View v)
    {
        switch( v.getId() )
        {
            case R.id.optionblock_right:    setRight();
                                            break;
            
            case R.id.optionblock_wrong:    setWrong();
                                            break;

            case R.id.optionblock_goaway:   setGoAway();
                                            break;

            default:    Log.d(MYTAG,"ERROR - practiceClick() passed invalied button id");
        
        }  // end switch( practice button )

        // load the next practice view without adding to the back stack
        PracticeCardSelector.setNextPracticeCard(currentTag,currentCard);
        
        practiceViewStatus = PracticeScreen.PRACTICE_VIEW_BLANK;
        XflashScreen.setPracticeOverride();
        Xflash.getActivity().onScreenTransition("practice",XflashScreen.DIRECTION_OPEN);

    }  // end practiceClick()

    
    // method called when any button in the options block is clicked
    public static void browseClick(View v)
    {
        switch( v.getId() )
        {
            case R.id.browseblock_last:     launchBrowseCard(XflashScreen.DIRECTION_CLOSE);
                                            break;
            
            case R.id.browseblock_next:     launchBrowseCard(XflashScreen.DIRECTION_OPEN);
                                            break;
        } 

    }  // end browseClick()

    
    // method called when user click to queue the extra screen
    public static void goRight()
    {
        // load the ExampleSentenceFragment to the fragment tab manager
        // Xflash.getActivity().onScreenTransition("example_sentence",XflashScreen.DIRECTION_OPEN);
        Log.d(MYTAG,">>>  >>>  PracticeFragment  ->  here we used to transition");
    }


    public static void dumpObservers()
    {
        activeTagObserver = null;
        onStopObserver = null;
        subscriptionObserver = null;
    }


    // method to subscribe/unsubscrible cards in user tags
    // set the card and screen transition for a browse click
    private static void launchBrowseCard(int inDirection)
    {
        PracticeCardSelector.setNextBrowseCard(currentTag,inDirection);
        Xflash.getActivity().onScreenTransition("practice",inDirection);
    } 


    // check/load saved practice counts from previous app exit
    private void loadSavedPracticeValues()
    {
        // check for a saved index
        XFApplication tempInstance = XFApplication.getInstance();
        SharedPreferences settings = tempInstance.getSharedPreferences(XFApplication.XFLASH_PREFNAME,0);

        // if there was anything index saved
        if( settings.contains("current_index") )
        {
            // set the index left on app exit
            int tempIndex = settings.getInt("current_index",0);
            currentTag.setCurrentIndex(tempIndex);

            // load the various card summary/count values
            rightStreak = settings.getInt("right_streak",0);
            wrongStreak = settings.getInt("wrong_streak",0);
            numRight    = settings.getInt("num_right",0);
            numWrong    = settings.getInt("num_wrong",0);
            numViewed   = settings.getInt("num_viewed",0);
            
            // clear the saved values
            SharedPreferences.Editor editor = settings.edit();
            editor.remove("current_index");
            editor.remove("right_streak");
            editor.remove("wrong_streak");
            editor.remove("num_right");
            editor.remove("num_wrong");
            editor.remove("num_viewed");
            
            editor.commit();
        }

    }  // end loadSavedPracticeValues()


    // toggles a card's starred status from the options menu
    private void toggleCardStarred()
    {
        Tag starredTag = TagPeer.starredWordsTag();

        if( TagPeer.cardIsMemberOfTag(currentCard,starredTag) )
        {
            TagPeer.cancelMembership(currentCard,starredTag);
        }
        else
        {
            TagPeer.subscribeCard(currentCard,starredTag);
        }

    }  // end toggleCarddStarred()

    
    // launches a model AddCardActivty from the options menu
    private void launchAddCard()
    {
        // load the card to AddCardToTagFragment, as it is the layout
        // and functionality for AddCardActivity
        AddCardToTagFragment.loadCard( currentCard.getCardId() );

        Xflash myContext = Xflash.getActivity();

        // launch the Activity - modal
        Intent myIntent = new Intent(myContext,AddCardActivity.class);
        myContext.startActivity(myIntent);

    }  // end launchAddCard()
    
  
    // launches a Twitter intent for this card
    private void tweetCard()
    {
        Xflash myContext = Xflash.getActivity();

        // setup an intent for tweeting
        String tweetString = currentCard.tweetContent();
        Intent tweetIntent = new Intent(Intent.ACTION_SEND);
        tweetIntent.putExtra(Intent.EXTRA_TEXT, tweetString );
        tweetIntent.setType("text/plain");
        
        // get the title and send the Intenet
        String chooserTitle = myContext.getResources().getString(R.string.twitter_chooser_title);
        myContext.startActivity( Intent.createChooser(tweetIntent, chooserTitle ) );


        
        // TODO - unfortunately it looks like there is no specific Twitter intent
        //      - to be broadcast.  There are a lot of different recommendations
        //      - on how to handle this, many of them gross hacks
        //
        //      - It seems like the best options is to use the ACTION_SEND intent
        //
        //      - Using the type "text/plain" brings up a LARGE number of possible
        //      - apps to use, however the type "application/twitter" is not
        //      - universally supported, and leaves out several important
        //      - options such as the actual official Twitter app.
        //
        //      - so, if we use "application/twitter" it will leave out important
        //      - apps.  HOWEVER if we use "text/plain" we've got a big problem in
        //      - that if our user once selected Gmail to always respond to the
        //      - "text/plain" SEND Intent type in another app, our tweet-card 
        //      - functionality would always open Gmail (or whatever else) instead.
        //
        //      - it may be challenging to obtain the desired behaviour here
        //
        //      - as an alternative, we can use the Intent.createChooser() functionality
        //      - to override the Android platform's handling of the SEND request.
        //      - this allow us to force the dialog to have a title (such as "Share
        //      - via Twitter") but does NOT support any functionality to select
        //      - a default response--i.e. the chooser will be displayed every time
        //      - the user taps "tweet card"
        //
        //      - please advise as to your preference

    }  // end tweetCard()


    // creates an email to notify Long Weekend about an error and 
    // launches it as a send-email intent
    private void fixCardEmail()
    {
        Resources res = Xflash.getActivity().getResources();
        
        Intent myIntent  = new Intent(Intent.ACTION_SEND);

        // set the email target
        myIntent.putExtra(android.content.Intent.EXTRA_EMAIL, new String[]{ "help@japaneseinaflash.com" });
        
        // set the email subject 
        String emailSubject = res.getString(R.string.fixcard_subject);
        myIntent.putExtra(android.content.Intent.EXTRA_SUBJECT,emailSubject);
        
        // set the email body - this is hard to read
        String emailBody = res.getString(R.string.fixcard_bodytop) 
                              + "  " + currentCard.getCardId() + "\n";
        emailBody = emailBody + res.getString(R.string.fixcard_bodyheadword) 
                              + "  " + currentCard.getJustHeadword() + "\n";
        emailBody = emailBody + res.getString(R.string.fixcard_bodymeaning) 
                              + "  " + currentCard.meaningWithoutMarkup() + "\n";
        emailBody = emailBody + res.getString(R.string.fixcard_bodytagid) 
                              + "  " + currentTag.getId() + "\n";
        emailBody = emailBody + res.getString(R.string.fixcard_bodytagname) 
                              + "  " + currentTag.getName() + "\n\n";

        myIntent.putExtra(android.content.Intent.EXTRA_TEXT,emailBody);

        // I believe this is the current email MIME?
        myIntent.setType("message/rfc5322");

        Xflash.getActivity().startActivity(myIntent);

    }  // end fixCardEmail()
   

    private void setupObservers()
    {
        XflashNotification theNotifier = XFApplication.getNotifier();

        if( subscriptionObserver == null )
        {
            // create and define behavior for newTagObserver
            subscriptionObserver = new Observer()
            {
                public void update(Observable obj,Object arg)
                {
                    updateFromSubscriptionObserver(arg);
                }
            };

            theNotifier.addSubscriptionObserver(subscriptionObserver);

        }  // end if( subscriptionObserver == null )
    
        if( activeTagObserver == null )
        {
            // create and define behavior for activeTagObserver 
            activeTagObserver = new Observer()
            {
                public void update(Observable obj,Object arg)
                {
                    updateFromActiveTagObserver();
                }
            };

            theNotifier.addActiveTagObserver(activeTagObserver);

        }  // end if( activeTagObserver == null )

        if( onStopObserver == null )
        {
            // create and define behavior for onStopObserver
            onStopObserver = new Observer()
            {
                public void update(Observable obj,Object arg)
                {
                    updateFromOnStopObserver();
                }
            };

            theNotifier.addOnStopObserver(onStopObserver);

        }  // end if( activeTagObserver == null )

    }  // end setupObservers()


    private void updateFromSubscriptionObserver(Object passedObject)
    {
        XflashNotification theNotifier = XFApplication.getNotifier();
        
        // only concern ourselves if the active tag changed
        if( currentTag.getId() == theNotifier.getTagIdPassed() )
        {
            JapaneseCard theCard = (JapaneseCard)passedObject;
            theCard.hydrate();

            if( theNotifier.getCardWasAdded() )
            {
                currentTag.addCardToActiveSet(theCard);
            }
            else
            {
                // if the card was removed from the active set
                currentTag.removeCardFromActiveSet(theCard);

                // if they are removing the card we're actually showing,
                // get a new card
                if( currentCard.equals(theCard) )
                {
                    PracticeCardSelector.setNextPracticeCard(currentTag,currentCard);
                    
                    // if we're actually on the practice tab right now, force
                    // reload of new card
                    if( practiceLayout != null )
                    {
                        if( this.isResumed() )
                        {
                            // if we're resumed, that means we're un-starring a presently
                            // acctive card in "My Starred Words" and as such, should
                            // reload the card/screen immediately
                            practiceViewStatus = PracticeScreen.PRACTICE_VIEW_BLANK;
        
                            XflashScreen.setPracticeOverride();
                            Xflash.getActivity().onScreenTransition("practice",XflashScreen.DIRECTION_OPEN);
                        }
                        else
                        {
                            // if we are NOT resumed, that means we have unsubscribed
                            // the active card in the active Tag modally via AddCardActivity,
                            // and as such must reset to a new card after the fragment
                            // has been resumed--i.e. after the user hits 'back' to exit
                            // the AddCardActivity
                            needToReloadCard = true;
                        }
                    }
                }
            } 

        }  // end if( card mod to active set ) 

    }  // end updateFromSubscriptionObserver()


    private void updateFromActiveTagObserver()
    {
        // when a new tag is set to active, reset all relevant values
        rightStreak = 0;
        wrongStreak = 0;
        numRight = 0;
        numWrong = 0;
        numViewed = 0;
    
        XflashScreen.resetPracticeScreen();

    }  // end updateFromStartStudyingObserver()


    // unfortunately we have to rely on a dispatch from Xflash to determine 
    // whether the app is paused/stopped due to how frequently we will be
    // cycling this fragment's lifecycle
    // otherwise we'd be saving the browse index ever single time the user
    // navigated to different card
    private void updateFromOnStopObserver()
    {
        // save the current card index
        // NOTE - current tag index is saved automatically 
        //      - in XflashSettings.setActiveTag()
        XFApplication tempInstance = XFApplication.getInstance();
        SharedPreferences settings = tempInstance.getSharedPreferences(XFApplication.XFLASH_PREFNAME,0);

        SharedPreferences.Editor editor = settings.edit();
        editor.putInt("current_index", currentTag.getCurrentIndex() );

        // save the various card summary/count values
        editor.putInt("right_streak",rightStreak);
        editor.putInt("wrong_streak",wrongStreak);
        editor.putInt("num_right",numRight);
        editor.putInt("num_wrong",numWrong);
        editor.putInt("num_viewed",numViewed);
    
        editor.commit();

    }  // end updateFromOnStopObserver()


}  // end PracticeFragment class declaration





