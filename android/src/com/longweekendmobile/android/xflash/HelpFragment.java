package com.longweekendmobile.android.xflash;

//  HelpFragment.java
//  Xflash
//
//  Created by Todd Presson on 1/26/2012.
//  Copyright 2012 Long Weekend LLC. All rights reserved.
//
//  public View onCreateView(LayoutInflater  ,ViewGroup  ,Bundle  )     @over
//
//  private void goAskUs()
//  private void pullHelpTopic(int  )

import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;

public class HelpFragment extends Fragment
{
    // private static final String MYTAG = "XFlash HelpFragment";
    
    private AlertDialog askDialog;


    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState)
    {
        // set our popup dialog instance to null
        askDialog = null;
        
        // inflate our layout for the Help fragment 
        LinearLayout helpLayout = (LinearLayout)inflater.inflate(R.layout.help, container, false);

        // load the title bar elements and pass them to the color manager
        RelativeLayout titleBar = (RelativeLayout)helpLayout.findViewById(R.id.help_heading);
        Button tempButton = (Button)helpLayout.findViewById(R.id.help_askusbutton);
           
        XflashSettings.setupColorScheme(titleBar,tempButton);
        
        // set a click listener for the 'ask us' button
        tempButton.setOnClickListener( new View.OnClickListener()
        {
            @Override
            public void onClick(View v)
            {
                goAskUs();
            }
        });

        // Resources object to pull our help topics
        Resources res = getResources();
        String[] topics;
        
        // set topics[] to strings defined in resources xml
        // depending on whether we're in Jflash or Cflash
        if( com.longweekendmobile.android.xflash.XFApplication.IS_JFLASH )
        {
            topics = res.getStringArray(R.array.help_topics_japanese);
        }
        else
        {
            topics = res.getStringArray(R.array.help_topics_chinese);
        }

        // pick up the child of our ScrollView so we can add rows
        LinearLayout myLayout = (LinearLayout)helpLayout.findViewById(R.id.help_list);
        
        int totalTopics = topics.length;
        for(int i = 0; i < totalTopics; i++)
        {
            // inflate our existing row resource (which is a RelativeLayout) for each 
            // row and tag the view with the row number of each particular help topic
            RelativeLayout toInflate = (RelativeLayout)inflater.inflate(R.layout.help_row,null);
            toInflate.setTag(i);

            if( i == 0 )
            {
                toInflate.setBackgroundResource( XflashSettings.getTopByColor() );
            }
            else if( i == ( totalTopics - 1 ) )
            {
                toInflate.setBackgroundResource( XflashSettings.getBottomByColor() );
            }
            else
            {
                toInflate.setBackgroundResource( XflashSettings.getMiddleByColor() );
            }
            
            // set the label
            TextView tempView = (TextView)toInflate.findViewById(R.id.help_label);
            tempView.setText( topics[i] );            

            // add a click listener
            toInflate.setOnClickListener( new OnClickListener()
            {
                public void onClick(View v) 
                {
                    int tempInt = (Integer)v.getTag(); 
                    
                    pullHelpTopic(tempInt);
                }

            });
 
            // add a divider before all except the first
            if( i > 0 )
            {
                FrameLayout divider = (FrameLayout)inflater.inflate(R.layout.divider,null);
                myLayout.addView(divider);
            }
            // add the new label/row to the LinearLayout (inside the ScrollView)
            myLayout.addView(toInflate);    
        
        } // end for loop

        return helpLayout;

    }  // end onCreateView


    // onClick method for the "ask us" button - pops a dialog
    private void goAskUs()
    {
        final Xflash inContext = Xflash.getActivity();

        AlertDialog.Builder builder;

        // inflate the dialog layout into a View object
        LayoutInflater inflater = (LayoutInflater)inContext.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View layout = inflater.inflate(R.layout.askus_dialog, (ViewGroup)inContext.findViewById(R.id.askus_root));

        builder = new AlertDialog.Builder(inContext);
        builder.setView(layout);

        askDialog = builder.create();
        askDialog.show();

        // we cannot reference our buttons until after the dialog.show()
        // method has been called - otherwise they don't "exist" 

        // set the "Visit Site" button 
        Button tempButton = (Button)askDialog.findViewById(R.id.sitebutton);
        tempButton.setOnClickListener( new OnClickListener()
        {
            @Override
            public void onClick(View v)
            {
                Intent myIntent = new Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://japaneseinaflash.com/support"));

                inContext.startActivity(myIntent);

                // dismiss, so we'll return to the overall help screen
                askDialog.dismiss();
            }
        });

        // set the "Send Email" button 
        tempButton = (Button)askDialog.findViewById(R.id.emailbutton);
        tempButton.setOnClickListener( new OnClickListener()
        {
            @Override
            public void onClick(View v)
            {
                Intent myIntent  = new Intent(Intent.ACTION_SEND);
                myIntent.putExtra(android.content.Intent.EXTRA_EMAIL, new String[]{ "help@japaneseinaflash.com" });
                myIntent.putExtra(android.content.Intent.EXTRA_SUBJECT,"Please make this awesome.");

                // I believe this is the current email MIME?
                myIntent.setType("message/rfc5322");

                inContext.startActivity(myIntent);

                // dismiss, so we'll return to the overall help screen
                askDialog.dismiss();
            }
        });

        // set the "No Thanks" button
        tempButton = (Button)askDialog.findViewById(R.id.closebutton);
        tempButton.setOnClickListener( new OnClickListener()
        {
            @Override
            public void onClick(View v)
            {
                askDialog.dismiss();
            }
        });

    }  // end goAskUs()


    // calls a new view activity for fragment tab layout 
    private void pullHelpTopic(int inId)
    {
        // set the help topic we are pulling
        HelpPageFragment.setHelpTopic(inId);

        // load the HelpPageFragment to the fragment tab manager
        Xflash.getActivity().onScreenTransition("help_page",XflashScreen.DIRECTION_OPEN);
    }


}  // end HelpFragment class declaration



